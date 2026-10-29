$ErrorActionPreference='Stop'
$appDir=Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'supervisor-task.ps1')
try{
  $info=Get-WidgetSupervisorInfo $appDir
  # An update transaction owns the install while it runs. Starting or migrating
  # the task here could clear its stop markers and race the GUI it is replacing.
  if(Test-WidgetSupervisorUpdateActive $info){return}
  $installed=Get-WidgetSupervisorTask $info
  if($installed){Start-WidgetSupervisorTask $appDir}else{Register-WidgetSupervisorTask $appDir|Out-Null}
  [IO.File]::WriteAllText((Join-Path $info.DataDir 'refresh.flag'),([DateTime]::UtcNow.ToString('o')+' '+[Guid]::NewGuid().ToString('N')))
  Remove-Item -LiteralPath (Join-Path $info.DataDir 'supervisor-start-error.txt') -ErrorAction SilentlyContinue
}catch{
  try{$configuration=Get-Content -LiteralPath (Join-Path $appDir 'installation.json') -Raw -Encoding UTF8|ConvertFrom-Json;[IO.File]::WriteAllText((Join-Path $configuration.dataDir 'supervisor-start-error.txt'),$_.Exception.ToString())}catch{}
  throw
}
