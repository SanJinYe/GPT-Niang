param([Parameter(Mandatory=$true)][string]$AppDir,[string]$LegacyOverlay,[switch]$FunctionsOnly)
$ErrorActionPreference='Stop'
function Copy-WidgetStoragePreferences([string]$Native,[string]$Overlay,[string]$Target) {
  $null=[IO.Directory]::CreateDirectory($Target)
  foreach($name in @('settings.json','providers.json','ark-connection.json','music-connection.json','music-sources.json','quotes.json','characters.json','audio-preferences.json','update-preferences.json')){
    $chosen=Join-Path $Native $name
    if(!(Test-Path -LiteralPath $chosen)){if(!$Overlay){continue};$chosen=Join-Path $Overlay $name}
    if(!(Test-Path -LiteralPath $chosen)){continue}
    $text=[IO.File]::ReadAllText($chosen,[Text.Encoding]::UTF8)
    $null=ConvertFrom-Json -InputObject $text -ErrorAction Stop
    [IO.File]::WriteAllText((Join-Path $Target $name),$text,[Text.UTF8Encoding]::new($false))
  }
  # Keep native order/enabled flags, only fill missing encrypted credentials.
  # Never decrypt or print a key; both original copies remain untouched.
  $file=Join-Path $Target 'providers.json'
  if($Overlay -and (Test-Path -LiteralPath $file) -and (Test-Path -LiteralPath (Join-Path $Overlay 'providers.json'))){
    $current=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($file))
    $legacy=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $Overlay 'providers.json')))
    foreach($row in $current){
      $old=@($legacy|Where-Object{$_.id-eq $row.id})|Select-Object -First 1
      if(!$old){continue}
      foreach($pair in @(@('keyProtected','keyEnv'),@('managementKeyProtected','managementKeyEnv'))){
        if(!$row.($pair[0]) -and $old.($pair[0])){
          $row|Add-Member -NotePropertyName $pair[0] -NotePropertyValue $old.($pair[0]) -Force
          $row|Add-Member -NotePropertyName $pair[1] -NotePropertyValue $old.($pair[1]) -Force
        }
      }
    }
    [IO.File]::WriteAllText($file,(ConvertTo-Json -InputObject @($current) -Depth 8),[Text.UTF8Encoding]::new($false))
  }
  foreach($folder in @('audio','characters')){
    foreach($base in @($Overlay,$Native)){
      if(!$base){continue};$from=Join-Path $base $folder
      if(Test-Path -LiteralPath $from){
        $to=Join-Path $Target $folder;$null=[IO.Directory]::CreateDirectory($to)
        foreach($f in @(Get-ChildItem -LiteralPath $from -File)){
          if($f.Attributes-band [IO.FileAttributes]::ReparsePoint){throw 'Linked personal asset cannot be migrated.'}
          Copy-Item -LiteralPath $f.FullName -Destination (Join-Path $to $f.Name) -Force
        }
      }
    }
  }
}
if($FunctionsOnly){return}
Add-Type -TypeDefinition @'
using System;using System.Runtime.InteropServices;using System.Text;
public static class WidgetMigrationPackage {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]public static extern int GetCurrentPackageFullName(ref uint length,StringBuilder name);
}
'@
$length=0
if([WidgetMigrationPackage]::GetCurrentPackageFullName([ref]$length,$null)-ne 15700){throw 'Run migration outside the packaged app (for example from Windows Task Scheduler).'}
$AppDir=[IO.Path]::GetFullPath($AppDir).TrimEnd('\')
$source=Split-Path $PSScriptRoot -Parent
. (Join-Path $AppDir 'runtime\supervisor-task.ps1')
. (Join-Path $AppDir 'runtime\update-common.ps1')
. (Join-Path $AppDir 'runtime\install-preflight.ps1')
$oldConfig=Read-WidgetUpdateJson (Join-Path $AppDir 'installation.json')
$root=Join-Path ([Environment]::GetFolderPath('UserProfile')) '.gpt-niang'
$newData=Join-Path $root 'state';$newAgent=Join-Path $root 'update-agent'
if($oldConfig.dataDir-ieq $newData -and $oldConfig.updateAgent-ieq $newAgent){
  $null=Assert-WidgetUpdateBinding $AppDir $newData $newAgent
  Write-Output 'Storage already uses the shared profile directory.';return
}
$oldInfo=Get-WidgetSupervisorInfo $AppDir
$oldTask=Get-WidgetSupervisorTask $oldInfo
$journal=Read-WidgetUpdateJson (Join-Path $oldInfo.AgentDir 'update-transaction.json')
if((Test-WidgetSupervisorUpdateActive $oldInfo)-or ($journal -and $journal.phase-notin @('committed','rolled-back'))){throw 'Complete or recover the current update before migrating storage.'}
foreach($path in @($root,$AppDir,$oldInfo.DataDir)){Assert-WidgetNoReparsePoint $path}
if($LegacyOverlay){Assert-WidgetNoReparsePoint $LegacyOverlay}
if((Test-Path -LiteralPath $newData)-or (Test-Path -LiteralPath $newAgent)){throw 'Target storage exists; inspect it before retrying migration.'}
$backup=Join-Path $root ('migration-backup-'+(Get-Date -Format yyyyMMdd-HHmmss))
$null=[IO.Directory]::CreateDirectory($backup)
$changed=@('storage-paths.ps1','supervisor-task.ps1','update-common.ps1','install-preflight.ps1','update.mjs','install-files.json','migrate-storage.ps1')
foreach($file in $changed){if(Test-Path -LiteralPath (Join-Path $AppDir ('runtime\'+$file))){Copy-Item -LiteralPath (Join-Path $AppDir ('runtime\'+$file)) -Destination (Join-Path $backup $file)}}
Copy-Item -LiteralPath (Join-Path $AppDir 'installation.json') -Destination (Join-Path $backup 'installation.json')
if($oldTask){[IO.File]::WriteAllText((Join-Path $backup 'task.xml'),(Export-ScheduledTask -TaskName $oldInfo.TaskName),[Text.UTF8Encoding]::new($false))}
$shortcut=[string]$oldConfig.startupShortcut
if($shortcut-and (Test-Path -LiteralPath $shortcut)){Copy-Item -LiteralPath $shortcut -Destination (Join-Path $backup 'startup.lnk')}
try{
  Stop-WidgetSupervisorTask $AppDir
  Stop-WidgetGui $AppDir $oldInfo.DataDir
  Copy-WidgetStoragePreferences $oldInfo.DataDir $LegacyOverlay $newData
  foreach($file in $changed){Copy-Item -LiteralPath (Join-Path $source ('runtime\'+$file)) -Destination (Join-Path $AppDir ('runtime\'+$file)) -Force}
  . (Join-Path $AppDir 'runtime\supervisor-task.ps1')
  . (Join-Path $AppDir 'runtime\update-common.ps1')
  $newConfig=$oldConfig|Select-Object *
  $newConfig.dataDir=$newData;$newConfig.updateAgent=$newAgent
  Install-WidgetUpdateAgent $AppDir $newData
  Write-WidgetSupervisorJson (Join-Path $AppDir 'installation.json') $newConfig
  # The old task was identity-checked above; replace only after new files exist.
  if($oldTask){Unregister-ScheduledTask -TaskName $oldInfo.TaskName -Confirm:$false -ErrorAction Stop}
  $null=Register-WidgetSupervisorTask $AppDir
  if($shortcut){
    $link=(New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
    $link.TargetPath=Join-Path $env:WINDIR 'System32\wscript.exe';$link.Arguments='"'+(Join-Path $newAgent 'agent-launch.vbs')+'"';$link.WorkingDirectory=$newAgent;$link.Save()
  }
  @{state=$newData;agent=$newAgent;backup=$backup;legacyRetained=$true}|ConvertTo-Json
}catch{
  $failure=$_.Exception.Message
  # Keep both data copies. Restore registration/configuration from backups.
  try{
    Stop-ScheduledTask -TaskName $oldInfo.TaskName -ErrorAction SilentlyContinue
    foreach($file in $changed){if(Test-Path -LiteralPath (Join-Path $backup $file)){Copy-Item -LiteralPath (Join-Path $backup $file) -Destination (Join-Path $AppDir ('runtime\'+$file)) -Force}}
    Copy-Item -LiteralPath (Join-Path $backup 'installation.json') -Destination (Join-Path $AppDir 'installation.json') -Force
    if(Test-Path -LiteralPath (Join-Path $backup 'startup.lnk')){Copy-Item -LiteralPath (Join-Path $backup 'startup.lnk') -Destination $shortcut -Force}
    if($oldTask){Register-ScheduledTask -TaskName $oldInfo.TaskName -Xml ([IO.File]::ReadAllText((Join-Path $backup 'task.xml'))) -Force|Out-Null}
    . (Join-Path $AppDir 'runtime\supervisor-task.ps1');. (Join-Path $AppDir 'runtime\update-common.ps1')
    Resume-WidgetSupervisor $AppDir
    if($oldTask){Start-ScheduledTask -TaskName $oldInfo.TaskName}
  }catch{throw ($failure+'; rollback failed: '+$_.Exception.Message+'; backups: '+$backup)}
  throw ($failure+'; previous entry restored; migration files retained at '+$root)
}
