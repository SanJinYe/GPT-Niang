$ErrorActionPreference='Stop'
$source=Split-Path $PSScriptRoot -Parent
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('gpt-niang-supervisor-'+[Guid]::NewGuid().ToString('N'))
$script:checks=0
$script:children=New-Object 'Collections.Generic.List[Diagnostics.Process]'
function Assert([bool]$Condition,[string]$Label){
  if(!$Condition){throw ('Assertion failed: '+$Label)}
  $script:checks++
  Write-Output ('PASS '+$Label)
}
function Assert-Throws([scriptblock]$Action,[string]$Label){
  try{& $Action|Out-Null}catch{$script:checks++;Write-Output ('PASS '+$Label);return}
  throw ('Expected failure: '+$Label)
}
function New-FakeLogonTrigger([string]$User){
  return [pscustomobject]@{Enabled=$true;UserId=$User;CimClass=[pscustomobject]@{CimClassName='MSFT_TaskLogonTrigger'}}
}
function New-FakeTimeTrigger([string]$Interval='PT1M',$Duration=$null,[bool]$StopAtEnd=$false){
  return [pscustomobject]@{Enabled=$true;CimClass=[pscustomobject]@{CimClassName='MSFT_TaskTimeTrigger'};Repetition=[pscustomobject]@{Interval=$Interval;Duration=$Duration;StopAtDurationEnd=$StopAtEnd}}
}
function New-FakeSettings([int]$RestartCount=3,[string]$RestartInterval='PT1M'){
  return [pscustomobject]@{MultipleInstances='IgnoreNew';ExecutionTimeLimit='PT0S';RestartCount=$RestartCount;RestartInterval=$RestartInterval;StartWhenAvailable=$true}
}
function New-FakeTask($Info,[string]$Mode){
  $legacy=$Mode-eq 'legacy'
  $arguments=if($legacy){'"'+(Join-Path $Info.AppDir 'supervisor.vbs')+'"'}else{$Info.Arguments}
  $working=if($legacy){$Info.AppDir}else{$Info.WorkingDirectory}
  $action=[pscustomobject]@{Execute=$Info.Execute;Arguments=$arguments;WorkingDirectory=$working}
  $triggers=if($legacy){@(New-FakeLogonTrigger $Info.Sid)}else{@((New-FakeLogonTrigger $Info.Sid),(New-FakeTimeTrigger))}
  $settings=New-FakeSettings $(if($legacy){0}else{3})
  return [pscustomobject]@{TaskName=$Info.TaskName;TaskPath=$Info.TaskPath;State='Ready';Principal=[pscustomobject]@{UserId=$Info.Sid;LogonType='Interactive';RunLevel='Limited'};Actions=@($action);Triggers=$triggers;Settings=$settings}
}
function Start-SupervisorChild([string]$App){
  $powerShell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  $start=New-Object Diagnostics.ProcessStartInfo
  $start.FileName=$powerShell
  $start.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $App 'runtime\supervisor.ps1')+'"'
  $start.UseShellExecute=$false
  $start.CreateNoWindow=$true
  $start.RedirectStandardError=$true
  $start.RedirectStandardOutput=$true
  $start.StandardErrorEncoding=[Text.Encoding]::UTF8
  $start.StandardOutputEncoding=[Text.Encoding]::UTF8
  $process=New-Object Diagnostics.Process
  $process.StartInfo=$start
  $null=$process.Start()
  $process|Add-Member ErrorTask ($process.StandardError.ReadToEndAsync())
  $process|Add-Member OutputTask ($process.StandardOutput.ReadToEndAsync())
  $script:children.Add($process)
  return $process
}
function Wait-ChildExit($Process,[int]$Seconds=25){
  if(!$Process.WaitForExit($Seconds*1000)){throw 'Supervisor child did not exit.'}
  return $Process.ExitCode
}
function Wait-SupervisorStatus([string]$DataDir,[int]$Seconds=25){
  $deadline=[DateTime]::UtcNow.AddSeconds($Seconds)
  do{
    try{
      $status=Get-Content -LiteralPath (Join-Path $DataDir 'supervisor-status.json') -Raw -Encoding UTF8|ConvertFrom-Json
      if($status){return $status}
    }catch{}
    Start-Sleep -Milliseconds 100
  }while([DateTime]::UtcNow-lt $deadline)
  throw 'Supervisor did not publish a heartbeat.'
}
try{
  $null=New-Item -ItemType Directory -Path $testRoot -Force
  $app=Join-Path $testRoot 'app'
  $agent=Join-Path $testRoot 'agent'
  $data=Join-Path $testRoot 'data'
  $null=New-Item -ItemType Directory -Path $app -Force
  $null=New-Item -ItemType Directory -Path $agent -Force
  $null=New-Item -ItemType Directory -Path $data -Force
  Copy-Item -LiteralPath (Join-Path $source 'runtime') -Destination $app -Recurse
  [IO.File]::WriteAllText((Join-Path $app 'widget.ps1'),'# isolated supervisor test widget',[Text.UTF8Encoding]::new($false))
  [IO.File]::WriteAllText((Join-Path $app 'supervisor.vbs'),'# isolated supervisor test launcher',[Text.UTF8Encoding]::new($false))
  $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  . (Join-Path $app 'runtime\supervisor-task.ps1')
  . (Join-Path $app 'runtime\update-common.ps1')
  function Get-WidgetUpdateAgentDir {return $script:agent}
  $script:agent=$agent
  Write-WidgetSupervisorJson (Join-Path $app 'installation.json') @{appDir=$app;dataDir=$data;updateAgent=$agent}
  Write-WidgetSupervisorJson (Join-Path $agent 'binding.json') @{sid=$sid;appDir=$app;dataDir=$data}
  $info=Get-WidgetSupervisorInfo $app

  # The real cmdlets build the definition locally without touching a task. The
  # sandbox user has no Task Scheduler CIM access, so this is skipped there.
  try{
    $realIssues=@(Get-WidgetSupervisorTaskPolicyIssues (New-WidgetSupervisorTaskDefinition $info) $info)
    Assert ($realIssues.Count-eq 0) ('real Windows task definition satisfies the recovery policy'+$(if($realIssues.Count){': '+($realIssues -join ',')}else{''}))
  }catch{
    if($_.CategoryInfo.Category-eq 'PermissionDenied' -or $_.Exception.Message-match '0x80041003'){Write-Output 'SKIP real task definition requires Task Scheduler CIM access (sandbox); parent must verify'}
    else{throw}
  }

  # Command substitution covers Task Scheduler and process scans; no real task
  # or real widget is read or modified by the migration checks.
  $script:tasks=@()
  $script:registered=0;$script:starts=0;$script:stops=0;$script:lastDefinition=$null
  $script:processes=@()
  $script:selfProcess=[pscustomobject]@{ProcessId=$PID;CommandLine='powershell.exe -NoProfile -File "C:\foreign\runner.ps1"'}
  function Get-CimInstance {
    param($ClassName,[string]$Filter)
    if($Filter-eq ('ProcessId='+$PID)){return $script:selfProcess}
    return $script:processes
  }
  function Get-ScheduledTask {param($TaskName,$TaskPath) return $script:tasks}
  function Start-ScheduledTask {param($TaskName,$TaskPath) $script:starts++;foreach($task in @($script:tasks)){$task.State='Running'}}
  function Stop-ScheduledTask {param($TaskName,$TaskPath) $script:stops++;foreach($task in @($script:tasks)){$task.State='Ready'}}
  function Register-ScheduledTask {
    param($TaskName,$TaskPath,$InputObject,[switch]$Force)
    $script:registered++
    $script:lastDefinition=$InputObject
    $script:tasks=@([pscustomobject]@{TaskName=$TaskName;TaskPath=$TaskPath;State='Ready';Principal=$InputObject.Principal;Actions=@($InputObject.Actions);Triggers=@($InputObject.Triggers);Settings=$InputObject.Settings})
  }
  function New-ScheduledTaskAction {param($Execute,$Argument,$WorkingDirectory) [pscustomobject]@{Execute=$Execute;Arguments=$Argument;WorkingDirectory=$WorkingDirectory}}
  function New-ScheduledTaskPrincipal {param($UserId,$LogonType,$RunLevel) [pscustomobject]@{UserId=$UserId;LogonType=[string]$LogonType;RunLevel=[string]$RunLevel}}
  function New-ScheduledTaskTrigger {
    param([switch]$AtLogOn,[switch]$Once,$User,$At,$RepetitionInterval)
    if($AtLogOn){return New-FakeLogonTrigger $User}
    return New-FakeTimeTrigger
  }
  function New-ScheduledTaskSettingsSet {
    param([switch]$AllowStartIfOnBatteries,[switch]$DontStopIfGoingOnBatteries,$ExecutionTimeLimit,[string]$MultipleInstances,[switch]$StartWhenAvailable,[switch]$Hidden,[int]$RestartCount,$RestartInterval)
    return New-FakeSettings $RestartCount 'PT1M'
  }
  function New-ScheduledTask {
    param($Action,$Principal,$Trigger,$Settings,$Description)
    return [pscustomobject]@{Actions=@($Action);Principal=$Principal;Triggers=@($Trigger);Settings=$Settings;Description=$Description}
  }

  $current=New-FakeTask $info 'current'
  $legacy=New-FakeTask $info 'legacy'
  Assert ((@(Get-WidgetSupervisorTaskPolicyIssues $current $info)).Count-eq 0) 'current two-trigger policy is accepted'
  Assert (@(Get-WidgetSupervisorTaskPolicyIssues $legacy $info)-contains 'recovery-trigger') 'logon-only task is detected as stale'
  Assert ((@(Get-WidgetSupervisorTaskPolicyIssues (New-FakeTask $info 'current') $info)).Count-eq 0) 'policy check is repeatable'
  $staleCount=New-FakeTask $info 'current';$staleCount.Settings.RestartCount=0
  Assert (@(Get-WidgetSupervisorTaskPolicyIssues $staleCount $info)-contains 'restart-count') 'missing restart policy is detected'
  $staleInterval=New-FakeTask $info 'current';$staleInterval.Triggers[1].Repetition.Interval='PT5M'
  Assert (@(Get-WidgetSupervisorTaskPolicyIssues $staleInterval $info)-contains 'recovery-interval') 'wrong repetition interval is detected'
  $limited=New-FakeTask $info 'current';$limited.Settings.ExecutionTimeLimit='PT1H'
  Assert (@(Get-WidgetSupervisorTaskPolicyIssues $limited $info)-contains 'execution-limit') 'bounded execution time is detected'
  $stopAtEnd=New-FakeTask $info 'current';$stopAtEnd.Triggers[1].Repetition.Duration='PT1M';$stopAtEnd.Triggers[1].Repetition.StopAtDurationEnd=$true
  Assert (@(Get-WidgetSupervisorTaskPolicyIssues $stopAtEnd $info)-contains 'recovery-duration') 'finite repetition duration is detected'
  $bounded=New-FakeTask $info 'current';$bounded.Triggers[1].Repetition.Duration='PT1M'
  Assert (@(Get-WidgetSupervisorTaskPolicyIssues $bounded $info)-contains 'recovery-duration') 'bounded repetition duration is detected without stop-at-end'
  $indefinite=New-FakeTask $info 'current';$indefinite.Triggers[1].Repetition.Duration='P10675199DT2H48M5.4775807S'
  Assert ((@(Get-WidgetSupervisorTaskPolicyIssues $indefinite $info)).Count-eq 0) 'Task Scheduler indefinite repetition duration is accepted'
  Assert (!(Test-WidgetSupervisorTaskAction $legacy $info)) 'legacy action is not treated as current'

  # Old task upgrade, then idempotent re-run.
  $script:tasks=@(New-FakeTask $info 'legacy')
  $null=Register-WidgetSupervisorTask $app
  Assert ($script:registered-eq 1) 'legacy installation registers the recovery policy'
  Assert (@($script:tasks[0].Triggers).Count-eq 2) 'upgraded task has logon and minute recovery triggers'
  Assert ($script:tasks[0].Settings.RestartCount-eq 3) 'upgraded task has restart count 3'
  Assert ($script:tasks[0].Settings.MultipleInstances-eq 'IgnoreNew') 'upgraded task keeps IgnoreNew'
  Assert ($script:starts-ge 1) 'upgraded task is started'
  Assert (!(Test-Path -LiteralPath (Join-Path $data 'supervisor-task-pending.json'))) 'successful upgrade clears any pending marker'
  $registeredAfterUpgrade=$script:registered
  $null=Register-WidgetSupervisorTask $app
  Assert ($script:registered-eq $registeredAfterUpgrade) 'second registration is idempotent'
  Assert ($script:stops-eq 0) 'idempotent registration does not stop a running supervisor'

  # A stale definition on a running task is replaced exactly once.
  $script:tasks=@(New-FakeTask $info 'legacy');$script:tasks[0].State='Running'
  $stopsBefore=$script:stops;$registeredBefore=$script:registered
  $null=Register-WidgetSupervisorTask $app
  Assert ($script:stops-eq $stopsBefore+1) 'running stale task is stopped before replacement'
  Assert ($script:registered-eq $registeredBefore+1) 'running stale task definition is replaced'

  # Self-hosted recovery must never re-register or stop its own task.
  $script:tasks=@(New-FakeTask $info 'legacy');$script:tasks[0].State='Running'
  $script:selfProcess.CommandLine='powershell.exe -NoProfile -File "'+(Join-Path $agent 'update-agent.ps1')+'" -Supervisor'
  $registeredBefore=$script:registered;$stopsBefore=$script:stops;$startsBefore=$script:starts
  $null=Register-WidgetSupervisorTask $app
  Assert ($script:registered-eq $registeredBefore) 'self-hosted recovery does not replace its own task'
  Assert ($script:stops-eq $stopsBefore) 'self-hosted recovery does not stop its own task'
  Assert ($script:starts-eq $startsBefore) 'self-hosted recovery does not start a duplicate task instance'
  $pendingFile=Join-Path $data 'supervisor-task-pending.json'
  Assert (Test-Path -LiteralPath $pendingFile) 'deferred self-hosted upgrade is recorded'
  $pending=Get-Content -LiteralPath $pendingFile -Raw -Encoding UTF8|ConvertFrom-Json
  Assert ($pending.reason-eq 'self-hosted' -and @($pending.problems).Count-gt 0) 'deferred record explains why migration was postponed'
  $stopFlag=Join-Path $data 'supervisor-stop.flag'
  Stop-WidgetSupervisorTask $app
  Assert ($script:stops-eq $stopsBefore) 'explicit stop from the task entry does not stop itself'
  Assert (Test-Path -LiteralPath $stopFlag) 'stop request is still written for other supervisor instances'

  # A normal launcher migrates the same stale definition.
  $script:selfProcess.CommandLine='powershell.exe -NoProfile -File "C:\foreign\runner.ps1"'
  $script:tasks=@(New-FakeTask $info 'legacy')
  $registeredBefore=$script:registered
  $null=Start-WidgetSupervisorTask $app
  Assert ($script:registered-eq $registeredBefore+1) 'normal start upgrades a stale installed task'
  Assert (!(Test-Path -LiteralPath $pendingFile)) 'normal upgrade clears the deferred marker'
  $script:tasks=@(New-FakeTask $info 'current')
  $registeredBefore=$script:registered;$startsBefore=$script:starts
  $null=Start-WidgetSupervisorTask $app
  Assert ($script:registered-eq $registeredBefore) 'current task is not re-registered by every start'
  Assert ($script:starts-eq $startsBefore+1) 'current task is started without replacement'
  Assert (!(Test-Path -LiteralPath (Join-Path $data 'supervisor-stop.flag'))) 'explicit start resumes app flags'

  # Stable agent module sync: an upgrade must refresh the copy used by the task.
  $agentModule=Join-Path $agent 'supervisor-task.ps1'
  [IO.File]::WriteAllText($agentModule,'stale agent copy',[Text.UTF8Encoding]::new($false))
  $appModule=Join-Path $app 'runtime\supervisor-task.ps1'
  [IO.File]::AppendAllText($appModule,[Environment]::NewLine+'# stable-sync-marker'+[Environment]::NewLine,[Text.UTF8Encoding]::new($false))
  Install-WidgetUpdateAgent $app $data
  Assert ((Get-Content -LiteralPath $agentModule -Raw -Encoding UTF8)-match 'stable-sync-marker') 'stable agent refreshes supervisor-task.ps1 during install'
  Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($agentModule))-eq [Convert]::ToBase64String([IO.File]::ReadAllBytes($appModule))) 'stable supervisor module is byte-identical after sync'
  Assert (Test-Path -LiteralPath (Join-Path $agent 'agent-supervisor.vbs')) 'stable agent keeps the scheduled entry script'

  # ---- supervisor loop helpers and observable behavior ----
  . (Join-Path $source 'runtime\supervisor.ps1') -FunctionsOnly
  $hosts=@([pscustomobject]@{handle=10;pid=20;started=30;visible=$true})
  Assert (Test-WidgetSupervisorPause ([pscustomobject]@{host=10;hostPid=20;hostStarted=30}) $hosts) 'pause matches the same host window'
  Assert (!(Test-WidgetSupervisorPause ([pscustomobject]@{host=10;hostPid=21;hostStarted=30}) $hosts)) 'pause rejects a new host with the same window handle'
  Assert (!(Test-WidgetSupervisorPause ([pscustomobject]@{host=10;hostPid=20;hostStarted=31}) $hosts)) 'pause rejects a reused handle from a restarted host'
  Assert (Test-WidgetSupervisorPause ([pscustomobject]@{desktop=$true}) $hosts) 'desktop pause does not depend on a host'
  Assert (!(Test-WidgetSupervisorPause $null $hosts)) 'missing pause file is not paused'

  $hostKey=Get-WidgetSupervisorHostKey $hosts
  $reopened=@([pscustomobject]@{handle=10;pid=21;started=31;visible=$true})
  Assert ($hostKey-ne (Get-WidgetSupervisorHostKey $reopened)) 'reopened host with a reused handle changes the host key'
  Assert ($hostKey-eq (Get-WidgetSupervisorHostKey (@($hosts)+@([pscustomobject]@{handle=11;pid=22;started=33;visible=$false})))) 'hidden windows do not change the visible host key'

  $process=Get-Process -Id $PID
  $startedAt=$process.StartTime.ToUniversalTime()
  $command='powershell.exe -NoProfile -File "'+(Join-Path $source 'widget.ps1')+'"'
  $runtime=[pscustomobject]@{pid=$PID;widget=1;processStartedAt=$startedAt.ToString('o');startedAt=$startedAt.ToString('o')}
  Assert (Test-WidgetSupervisorGuiRecord $runtime 'powershell' $startedAt $command $source) 'GUI record accepts the live owning process'
  Assert (!(Test-WidgetSupervisorGuiRecord $runtime 'powershell' $startedAt.AddSeconds(5) $command $source)) 'GUI record rejects a reused PID with a new start time'
  Assert (!(Test-WidgetSupervisorGuiRecord $runtime 'powershell' $startedAt ('powershell.exe -File "C:\foreign\widget.ps1"') $source)) 'GUI record rejects a foreign widget script'
  Assert (!(Test-WidgetSupervisorGuiRecord ([pscustomobject]@{pid='invalid';startedAt=$startedAt.ToString('o')}) 'powershell' $startedAt $command $source)) 'GUI record rejects an invalid PID'
  $legacyRuntime=[pscustomobject]@{pid=$PID;startedAt=$startedAt.ToString('o')}
  Assert (Test-WidgetSupervisorGuiRecord $legacyRuntime 'powershell' $startedAt $command $source) 'legacy runtime record within the startup window is accepted'
  $oldRuntime=[pscustomobject]@{pid=$PID;startedAt=$startedAt.AddMinutes(-5).ToString('o')}
  Assert (!(Test-WidgetSupervisorGuiRecord $oldRuntime 'powershell' $startedAt $command $source)) 'legacy runtime record outside the startup window is rejected'
  $process.Dispose()

  $script:processes=@([pscustomobject]@{ProcessId=999999;CommandLine='powershell.exe -File "'+(Join-Path $source 'runtime\start-widget.ps1')+'"'})
  Assert (@(Get-WidgetSupervisorStartingGui $source).Count-eq 1) 'a live widget launcher suppresses a duplicate launch'
  $script:processes=@([pscustomobject]@{ProcessId=999999;CommandLine='powershell.exe -File "C:\foreign\start-widget.ps1"'})
  Assert (@(Get-WidgetSupervisorStartingGui $source).Count-eq 0) 'foreign launchers do not suppress the local widget'

  $now=[DateTime]::UtcNow
  Assert (Test-WidgetSupervisorShouldLaunch $false $true 0 $false $false $false ([DateTime]::MinValue) $now) 'desktop mode launches without a host'
  Assert (Test-WidgetSupervisorShouldLaunch $false $false 1 $false $false $false ([DateTime]::MinValue) $now) 'visible host triggers a launch'
  Assert (!(Test-WidgetSupervisorShouldLaunch $false $false 0 $false $false $false ([DateTime]::MinValue) $now)) 'no host does not launch in follow mode'
  Assert (!(Test-WidgetSupervisorShouldLaunch $true $false 1 $false $false $false ([DateTime]::MinValue) $now)) 'pause suppresses a launch'
  Assert (!(Test-WidgetSupervisorShouldLaunch $false $false 1 $true $false $false ([DateTime]::MinValue) $now)) 'an existing widget is not duplicated'
  Assert (!(Test-WidgetSupervisorShouldLaunch $false $false 1 $false $true $false ([DateTime]::MinValue) $now)) 'a pending launch is not duplicated'
  Assert (!(Test-WidgetSupervisorShouldLaunch $false $false 1 $false $false $true ([DateTime]::MinValue) $now)) 'an active update suppresses GUI launch'
  Assert (!(Test-WidgetSupervisorShouldLaunch $false $false 1 $false $false $false $now.AddSeconds(5) $now)) 'launch backoff is respected'

  $updateApp=Join-Path $testRoot 'update-app'
  $updateAgent=Join-Path $testRoot 'update-agent'
  $updateData=Join-Path $testRoot 'update-data'
  $null=New-Item -ItemType Directory -Path $updateApp,$updateAgent,$updateData -Force
  $updateInfo=[pscustomobject]@{AppDir=$updateApp;DataDir=$updateData;AgentDir=$updateAgent;WorkingDirectory=$updateAgent}
  Assert (!(Test-WidgetSupervisorUpdateActive $updateInfo)) 'idle installation is not updating'
  Write-WidgetSupervisorJson (Join-Path $updateData 'update-installing.json') @{token='fixture'}
  Assert (Test-WidgetSupervisorUpdateActive $updateInfo) 'installation flag suppresses GUI launch'
  Remove-Item -LiteralPath (Join-Path $updateData 'update-installing.json')
  Write-WidgetSupervisorJson (Join-Path $updateAgent 'update-transaction.json') @{phase='stopping'}
  Assert (Test-WidgetSupervisorUpdateActive $updateInfo) 'stopping transaction suppresses GUI launch'
  Write-WidgetSupervisorJson (Join-Path $updateAgent 'update-transaction.json') @{phase='committed'}
  Assert (!(Test-WidgetSupervisorUpdateActive $updateInfo)) 'committed transaction does not block the GUI'
  [IO.File]::WriteAllText((Join-Path $updateAgent 'update-transaction.json'),'{invalid',[Text.UTF8Encoding]::new($false))
  Assert-Throws {Test-WidgetSupervisorUpdateActive $updateInfo} 'corrupt transaction is reported instead of allowing a potentially unsafe launch'

  # The launcher must leave the whole installation alone while an update owns it.
  $guardApp=Join-Path $testRoot 'guard-app'
  $guardData=Join-Path $testRoot 'guard-data'
  $guardRuntime=Join-Path $guardApp 'runtime'
  $null=New-Item -ItemType Directory -Path $guardRuntime,$guardData -Force
  Copy-Item -LiteralPath (Join-Path $source 'runtime\start-supervisor.ps1'),(Join-Path $source 'runtime\supervisor-task.ps1') -Destination $guardRuntime
  Write-WidgetSupervisorJson (Join-Path $guardApp 'installation.json') @{appDir=$guardApp;dataDir=$guardData}
  Write-WidgetSupervisorJson (Join-Path $guardData 'update-installing.json') @{token='fixture'}
  [IO.File]::WriteAllText((Join-Path $guardData 'supervisor-stop.flag'),'stop',[Text.UTF8Encoding]::new($false))
  $guard=New-Object Diagnostics.Process
  $guard.StartInfo.FileName=(Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe')
  $guard.StartInfo.Arguments='-NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $guardRuntime 'start-supervisor.ps1')+'"'
  $guard.StartInfo.UseShellExecute=$false
  $guard.StartInfo.CreateNoWindow=$true
  $guard.StartInfo.RedirectStandardError=$true
  $guard.StartInfo.RedirectStandardOutput=$true
  $null=$guard.Start()
  $guardError=$guard.StandardError.ReadToEndAsync()
  $null=$guard.WaitForExit(20000)
  if(!$guard.HasExited){$guard.Kill();$null=$guard.WaitForExit(5000);throw 'Launcher did not defer during an update.'}
  $guardOutput=$guardError.Result
  Assert ($guard.ExitCode-eq 0) ('launcher defers during an update: '+$guardOutput.Trim())
  Assert (!(Test-Path -LiteralPath (Join-Path $guardData 'refresh.flag'))) 'launcher does not request a refresh during an update'
  Assert (Test-Path -LiteralPath (Join-Path $guardData 'supervisor-stop.flag')) 'launcher does not clear the stop marker during an update'
  Assert (!(Test-Path -LiteralPath (Join-Path $guardData 'supervisor-start-error.txt'))) 'launcher does not touch the task during an update'
  $guard.Dispose()

  $exitDir=Join-Path $testRoot 'exit-record'
  Write-WidgetSupervisorExitRecord $exitDir 'fatal' ('x'*600) 'fixture-task' 'started'
  $exit=Get-Content -LiteralPath (Join-Path $exitDir 'supervisor-exit.json') -Raw -Encoding UTF8|ConvertFrom-Json
  Assert ($exit.pid-eq $PID -and $exit.reason-eq 'fatal' -and $exit.taskName-eq 'fixture-task') 'exit record identifies the process and reason'
  Assert ($exit.message.Length-eq 500) 'exit message is bounded'

  # Real loop: disabled and stop flags exit without clearing user state.
  $loopApp=Join-Path $testRoot 'loop-app'
  $loopData=Join-Path $testRoot 'loop-data'
  $loopRuntime=Join-Path $loopApp 'runtime'
  $null=New-Item -ItemType Directory -Path $loopRuntime,$loopData -Force
  Copy-Item -LiteralPath (Join-Path $source 'runtime\supervisor-task.ps1') -Destination $loopRuntime
  $loopText=[IO.File]::ReadAllText((Join-Path $source 'runtime\supervisor.ps1'))
  $loopText=$loopText.Replace('Local\GPTNiangSupervisor-',('Local\GPTNiangSupervisorTest-'+[Guid]::NewGuid().ToString('N')+'-'))
  [IO.File]::WriteAllText((Join-Path $loopRuntime 'supervisor.ps1'),$loopText,[Text.UTF8Encoding]::new($false))
  Write-WidgetSupervisorJson (Join-Path $loopApp 'installation.json') @{appDir=$loopApp;dataDir=$loopData}
  $disabledFlag=Join-Path $loopData 'supervisor-disabled.flag'
  $stopFlag=Join-Path $loopData 'supervisor-stop.flag'
  $loopExit=Join-Path $loopData 'supervisor-exit.json'
  [IO.File]::WriteAllText($disabledFlag,'disabled',[Text.UTF8Encoding]::new($false))
  $child=Start-SupervisorChild $loopApp
  Assert ((Wait-ChildExit $child)-eq 0) 'disabled supervisor exits successfully'
  Assert ((Get-Content -LiteralPath $loopExit -Raw -Encoding UTF8|ConvertFrom-Json).reason-eq 'disabled') 'disabled exit reason is recorded'
  Assert (Test-Path -LiteralPath $disabledFlag) 'disabled state is not cleared by the supervisor'
  Remove-Item -LiteralPath $loopExit
  Remove-Item -LiteralPath $disabledFlag
  [IO.File]::WriteAllText($stopFlag,'stop',[Text.UTF8Encoding]::new($false))
  $child=Start-SupervisorChild $loopApp
  Assert ((Wait-ChildExit $child)-eq 0) 'stop-requested supervisor exits successfully'
  Assert ((Get-Content -LiteralPath $loopExit -Raw -Encoding UTF8|ConvertFrom-Json).reason-eq 'stop-requested') 'stop exit reason is recorded'
  Assert (Test-Path -LiteralPath $stopFlag) 'stop flag is not cleared by the supervisor'
  Remove-Item -LiteralPath $loopExit
  Remove-Item -LiteralPath $stopFlag

  # Single instance and pause retention: the first owns the mutex, the second
  # exits without overwriting the first exit record.
  Write-WidgetSupervisorJson (Join-Path $loopData 'supervisor-pause.json') @{desktop=$true;at=[DateTime]::UtcNow.ToString('o')}
  $first=Start-SupervisorChild $loopApp
  $status=Wait-SupervisorStatus $loopData
  Assert ($status.pid-eq $first.Id) 'first supervisor publishes its heartbeat'
  Assert ([bool]$status.paused) 'desktop pause is visible in the heartbeat'
  $second=Start-SupervisorChild $loopApp
  Assert ((Wait-ChildExit $second)-eq 0) 'second supervisor exits cleanly on the mutex'
  Assert (!(Test-Path -LiteralPath $loopExit)) 'second supervisor does not overwrite the exit record'
  [IO.File]::WriteAllText($stopFlag,'stop',[Text.UTF8Encoding]::new($false))
  Assert ((Wait-ChildExit $first)-eq 0) 'first supervisor stops on request'
  $exit=Get-Content -LiteralPath $loopExit -Raw -Encoding UTF8|ConvertFrom-Json
  Assert ($exit.pid-eq $first.Id -and $exit.reason-eq 'stop-requested') 'stopped owner writes its own exit reason'
  Assert (Test-Path -LiteralPath (Join-Path $loopData 'supervisor-pause.json')) 'pause state survives supervisor restart'
  Assert (Test-Path -LiteralPath (Join-Path $loopData 'supervisor-status.json')) 'last status is retained after exit'

  Write-Output ("All $script:checks isolated supervisor assertions passed.")
}finally{
  foreach($child in $script:children){try{if(!$child.HasExited){$child.Kill();$null=$child.WaitForExit(2000)}}catch{};try{$child.Dispose()}catch{}}
  $resolved=[IO.Path]::GetFullPath($testRoot)
  $tempPrefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
  if(!$resolved.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved)-notlike 'gpt-niang-supervisor-*'){throw 'Unsafe test cleanup path.'}
  if([IO.Directory]::Exists($resolved)){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
