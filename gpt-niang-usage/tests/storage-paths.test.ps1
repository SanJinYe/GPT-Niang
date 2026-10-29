$ErrorActionPreference='Stop'
$app=Split-Path $PSScriptRoot -Parent
. (Join-Path $app 'runtime\storage-paths.ps1')
. (Join-Path $app 'runtime\update-common.ps1')
. (Join-Path $app 'runtime\migrate-storage.ps1') -AppDir $app -FunctionsOnly
function Assert($value,[string]$message){if(!$value){throw $message}}
$expected=Join-Path ([Environment]::GetFolderPath('UserProfile')) '.gpt-niang'
Assert ((Get-WidgetStorageRoot)-eq $expected) 'Storage must live outside virtualized AppData'
Assert ((Get-WidgetUpdateAgentDir)-eq (Join-Path $expected 'update-agent')) 'Stable entry must use shared storage'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('gpt-storage-'+[Guid]::NewGuid().ToString('N'))
try{
  $native=Join-Path $temp 'native';$overlay=Join-Path $temp 'overlay';$target=Join-Path $temp 'target'
  $null=New-Item -ItemType Directory -Path $native,$overlay
  function Put([string]$dir,[string]$file,$value){[IO.File]::WriteAllText((Join-Path $dir $file),(ConvertTo-Json -InputObject $value -Depth 8),[Text.UTF8Encoding]::new($false))}
  Put $native 'settings.json' @{scale=0.9}
  Put $overlay 'settings.json' @{scale=0.6}
  Put $overlay 'ark-connection.json' @{pythonPath='fixture-python';handoffPath='fixture-handoff'}
  Put $native 'providers.json' @(@{id='ark';enabled=$true},@{id='openrouter';enabled=$false;keyProtected='';keyEnv='OPENROUTER_API_KEY'},@{id='deepseek';enabled=$true;keyProtected='native-fixture';keyEnv='native'})
  Put $overlay 'providers.json' @(@{id='ark';enabled=$false},@{id='openrouter';enabled=$true;keyProtected='encrypted-fixture';keyEnv='saved'},@{id='deepseek';enabled=$false;keyProtected='old-fixture';keyEnv='old'})
  Put $overlay 'presence.json' @{pid=123}
  Put $native 'worker.lock' @{pid=456}
  Copy-WidgetStoragePreferences $native $overlay $target
  $settings=Get-Content (Join-Path $target 'settings.json') -Raw|ConvertFrom-Json
  Assert ($settings.scale-eq 0.9) 'Live settings must win over older overlay settings'
  Assert (Test-Path (Join-Path $target 'ark-connection.json')) 'Missing connections must be migrated'
  $rows=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $target 'providers.json')))
  Assert ($rows[0].id-eq 'ark' -and $rows[0].enabled) 'Native order and enabled state must survive'
  Assert (!$rows[1].enabled -and $rows[1].keyProtected-eq 'encrypted-fixture') 'Restore missing encrypted credentials without enabling a source'
  Assert ($rows[2].keyProtected-eq 'native-fixture') 'Existing encrypted credentials must never be replaced'
  Assert (!(Test-Path (Join-Path $target 'presence.json'))) 'Do not migrate stale process heartbeats'
  Assert (!(Test-Path (Join-Path $target 'worker.lock'))) 'Do not migrate stale locks'
  Assert (Test-Path (Join-Path $overlay 'providers.json')) 'Legacy files must remain available for rollback'
  [IO.File]::WriteAllText((Join-Path $native 'settings.json'),'{invalid')
  $failed=$false;try{Copy-WidgetStoragePreferences $native $overlay (Join-Path $temp 'invalid')}catch{$failed=$true}
  Assert $failed 'Invalid current preferences must fail instead of silently falling back'
  'PASS: shared storage, current preferences, missing connections, encrypted keys, no stale state and explicit failure'
}finally{
  $full=[IO.Path]::GetFullPath($temp)
  if(!$full.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\') -or [IO.Path]::GetFileName($full)-notlike 'gpt-storage-*'){throw 'Unsafe test cleanup'}
  Remove-Item -LiteralPath $full -Recurse -Force
}
