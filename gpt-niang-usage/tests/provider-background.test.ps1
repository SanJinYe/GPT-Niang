$ErrorActionPreference='Stop'
$script:appDir=Split-Path $PSScriptRoot -Parent
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/settings-window.ps1'),[Text.Encoding]::UTF8)))
$script:dataDir=Join-Path ([IO.Path]::GetTempPath()) ('niang-background-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($script:dataDir)|Out-Null
$oldCodex=$env:CODEX_HOME;$oldDb=$env:OPENCODE_DB
try{
 [IO.File]::WriteAllText((Join-Path $script:dataDir 'providers.json'),'[]')
 $env:CODEX_HOME=Join-Path $script:dataDir 'codex';$env:OPENCODE_DB=Join-Path $script:dataDir 'missing.db'
 $script:config=@{nodePath=(Get-Command node).Source};$script:settingsWindow=$null;$script:collapsed=$false;$script:bubbleMode='quota';$script:quotaProvider='openrouter'
 $script:ttlResets=0;function Restart-SceneTtl {$script:ttlResets++}
 Start-ProviderUsageQuery
 if(!$script:usageProcess){throw 'Query must start without a settings window'}
 if(!$script:usageProcess.WaitForExit(15000)){throw 'Query timed out'}
 Sync-ProviderUsage
 if($script:usageQueryFailed-or !$script:usageResult.at-or $script:usageProcess){throw ('Background query result not consumed: '+$script:usageErr.Result)}
 if($script:ttlResets-ne 1){throw 'Completed query must restart bubble expiry'}
 'PASS: query starts, completes and updates expiry without the settings window'
}finally{
 $env:CODEX_HOME=$oldCodex;$env:OPENCODE_DB=$oldDb
 if($script:usageProcess-and !$script:usageProcess.HasExited){$script:usageProcess.Kill()}
 $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath());$target=[IO.Path]::GetFullPath($script:dataDir)
 if(!$target.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe test cleanup path'}
 Remove-Item -LiteralPath $target -Recurse -Force
}
