param([switch]$CheckOnly,[switch]$FunctionsOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'supervisor-task.ps1')

function Test-WidgetSupervisorPause($Pause,$Hosts){
  if(!$Pause){return $false}
  if($Pause.desktop){return $true}
  foreach($item in @($Hosts)){
    if([long]$Pause.host-gt 0 -and [long]$item.handle-eq [long]$Pause.host){
      if([int]$Pause.hostPid-gt 0 -and [int]$item.pid-ne [int]$Pause.hostPid){continue}
      if([long]$Pause.hostStarted-gt 0 -and [long]$item.started-ne [long]$Pause.hostStarted){continue}
      return $true
    }
  }
  return $false
}

function Test-WidgetSupervisorGuiRecord {
  # Owner check for runtime.json. The PID alone is not an identity: Windows
  # reuses PIDs, so a foreign process may inherit the previous widget's number.
  param($Runtime,[string]$ProcessName,[DateTime]$ProcessStartedAt,[string]$CommandLine,[string]$AppDir)
  if(!$Runtime){return $false}
  $runtimePid=0
  if(![int]::TryParse([string]$Runtime.pid,[ref]$runtimePid) -or $runtimePid-le 0){return $false}
  if($ProcessName-notin @('powershell','pwsh')){return $false}
  if(![string]$CommandLine){return $false}
  $started=[DateTime]::MinValue
  if($Runtime.processStartedAt){
    if(![DateTime]::TryParse([string]$Runtime.processStartedAt,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$started)){return $false}
    if($started.ToUniversalTime()-ne $ProcessStartedAt.ToUniversalTime()){return $false}
  } else {
    if(!$Runtime.startedAt){return $false}
    if(![DateTime]::TryParse([string]$Runtime.startedAt,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$started)){return $false}
    $gap=($started.ToUniversalTime()-$ProcessStartedAt.ToUniversalTime()).TotalSeconds
    if($gap-lt 0 -or $gap-gt 120){return $false}
  }
  $scriptFile=Join-Path $AppDir 'widget.ps1'
  return $CommandLine.IndexOf(('"'+$scriptFile+'"'),[StringComparison]::OrdinalIgnoreCase)-ge 0
}

function Get-WidgetSupervisorRunningGui([string]$DataDir,[string]$ExpectedAppDir){
  $process=$null
  try{
    $runtime=Get-Content -LiteralPath (Join-Path $DataDir 'runtime.json') -Raw -Encoding UTF8|ConvertFrom-Json
    $handle=[IntPtr]([long]$runtime.widget)
    if(![GptWidgetSupervisorNative]::IsWindow($handle) -or [GptWidgetSupervisorNative]::ProcessId($handle)-ne [int]$runtime.pid){return $false}
    $process=Get-Process -Id ([int]$runtime.pid) -ErrorAction Stop
    $command=(Get-CimInstance Win32_Process -Filter ('ProcessId='+[int]$runtime.pid) -ErrorAction Stop).CommandLine
    return Test-WidgetSupervisorGuiRecord $runtime $process.ProcessName $process.StartTime.ToUniversalTime() ([string]$command) $ExpectedAppDir
  }catch{return $false}finally{if($process){$process.Dispose()}}
}

function Get-WidgetSupervisorStartingGui([string]$AppDir){
  # A previous supervisor may have launched the widget just before it was
  # killed. runtime.json appears late in startup, so also respect a live
  # launcher to avoid a second GUI in that window.
  $expectedStart='"'+(Join-Path $AppDir 'runtime\start-widget.ps1')+'"'
  $expectedWidget='"'+(Join-Path $AppDir 'widget.ps1')+'"'
  return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop|Where-Object{
    $_.ProcessId-ne $PID -and [string]$_.CommandLine -and ($_.CommandLine.IndexOf($expectedStart,[StringComparison]::OrdinalIgnoreCase)-ge 0 -or $_.CommandLine.IndexOf($expectedWidget,[StringComparison]::OrdinalIgnoreCase)-ge 0)
  })
}

function Get-WidgetSupervisorHostKey($Hosts){
  return (@(@($Hosts)|Where-Object{$_.visible}|Sort-Object handle|ForEach-Object{'{0}:{1}:{2}'-f $_.handle,$_.pid,$_.started}) -join '|')
}

function Test-WidgetSupervisorShouldLaunch {
  param([bool]$Paused,[bool]$Desktop,[int]$VisibleCount,[bool]$Running,[bool]$Pending,[bool]$UpdateActive,[DateTime]$NextLaunch,[DateTime]$Now)
  return (!$Paused -and !$UpdateActive -and ($Desktop -or $VisibleCount-gt 0) -and !$Running -and !$Pending -and $Now-ge $NextLaunch)
}

function Write-WidgetSupervisorExitRecord {
  # Hard process termination cannot write this file. An absent record therefore
  # means "no clean exit was observed", not that the supervisor is healthy.
  param([string]$DataDir,[string]$Reason,[string]$Message,[string]$TaskName,[string]$ProcessStartedAt)
  $value=@{pid=$PID;processStartedAt=$ProcessStartedAt;at=[DateTime]::UtcNow.ToString('o');reason=$Reason;taskName=$TaskName}
  if($Message){$text=[string]$Message;if($text.Length-gt 500){$text=$text.Substring(0,500)};$value.message=$text}
  Write-WidgetSupervisorJson (Join-Path $DataDir 'supervisor-exit.json') $value
}

if($FunctionsOnly){return}

$appDir=Split-Path $PSScriptRoot -Parent
$info=Get-WidgetSupervisorInfo $appDir
if(!('GptWidgetSupervisorNative' -as [type])){
Add-Type -TypeDefinition @'
using System;using System.Collections.Generic;using System.Diagnostics;using System.Runtime.InteropServices;using System.Text;
public sealed class GptWidgetSupervisorHost {public long handle;public int pid;public long started;public bool visible;}
public static class GptWidgetSupervisorNative {
 static readonly int Session=CurrentSession();
 static int CurrentSession(){using(var process=Process.GetCurrentProcess())return process.SessionId;}
 public delegate bool EnumProc(IntPtr h,IntPtr p);
 [DllImport("user32.dll")]static extern bool EnumWindows(EnumProc cb,IntPtr p);
 [DllImport("user32.dll")]public static extern bool IsWindow(IntPtr h);
 [DllImport("user32.dll")]static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")]static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr h,out uint pid);
 [DllImport("user32.dll",EntryPoint="GetWindowLongPtrW")]static extern IntPtr GetWindowLongPtr(IntPtr h,int index);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetClassName(IntPtr h,StringBuilder text,int size);
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]static extern int GetWindowText(IntPtr h,StringBuilder text,int size);
 [DllImport("dwmapi.dll")]static extern int DwmGetWindowAttribute(IntPtr h,int attribute,out uint value,int size);
 public static bool MainWindowStyle(long style,long extended){return (extended&0x80)==0&&(extended&0x08000000)==0&&(extended&0x40000)!=0&&(style&0x10000)!=0;}
 public static int ProcessId(IntPtr h){uint value;GetWindowThreadProcessId(h,out value);return (int)value;}
 static bool CodexProcess(Process process){
  if(process.SessionId!=Session)return false;
  if(!process.ProcessName.Equals("ChatGPT",StringComparison.OrdinalIgnoreCase)&&!process.ProcessName.Equals("Codex",StringComparison.OrdinalIgnoreCase))return false;
  string file=process.MainModule.FileName;
  return file.IndexOf("\\OpenAI.Codex_",StringComparison.OrdinalIgnoreCase)>=0||file.IndexOf("\\OpenAI\\Codex\\",StringComparison.OrdinalIgnoreCase)>=0;
 }
 public static GptWidgetSupervisorHost Inspect(IntPtr h){
  try{
   if(!IsWindow(h)||!MainWindowStyle(GetWindowLongPtr(h,-16).ToInt64(),GetWindowLongPtr(h,-20).ToInt64()))return null;
   var text=new StringBuilder(256);GetWindowText(h,text,256);if(text.Length==0)return null;
   var cls=new StringBuilder(128);GetClassName(h,cls,128);if(cls.ToString()!="Chrome_WidgetWin_1")return null;
   using(var process=Process.GetProcessById(ProcessId(h))){
    if(!CodexProcess(process))return null;
    uint cloaked;bool visible=IsWindowVisible(h)&&!IsIconic(h)&&(DwmGetWindowAttribute(h,14,out cloaked,4)!=0||cloaked==0);
    return new GptWidgetSupervisorHost{handle=h.ToInt64(),pid=process.Id,started=process.StartTime.ToUniversalTime().Ticks,visible=visible};
   }
  }catch{return null;}
 }
 public static GptWidgetSupervisorHost[] Hosts(){var hosts=new List<GptWidgetSupervisorHost>();EnumWindows((h,p)=>{var host=Inspect(h);if(host!=null)hosts.Add(host);return true;},IntPtr.Zero);return hosts.ToArray();}
}
'@
}

if($CheckOnly){return [pscustomobject]@{ok=$true;info=$info;hosts=@([GptWidgetSupervisorNative]::Hosts());updateActive=(Test-WidgetSupervisorUpdateActive $info)}}

$mutex=[Threading.Mutex]::new($false,('Local\GPTNiangSupervisor-'+$info.Sid))
$owned=$false
try{$owned=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$owned=$true}
if(!$owned){$mutex.Dispose();exit 0}
$pauseFile=Join-Path $info.DataDir 'supervisor-pause.json'
$nextLaunch=[DateTime]::MinValue
$nextStatus=[DateTime]::MinValue
$lastVisibleHostKey=''
$pendingGui=$null
$lastError=''
$supervisorProcess=Get-Process -Id $PID
try{$processStartedAt=$supervisorProcess.StartTime.ToUniversalTime().ToString('o')}finally{$supervisorProcess.Dispose()}
$exitReason='fatal'
$exitMessage=$null
try{
  while($true){
    if(Test-Path -LiteralPath (Join-Path $info.DataDir 'supervisor-disabled.flag')){$exitReason='disabled';break}
    if(Test-Path -LiteralPath (Join-Path $info.DataDir 'supervisor-stop.flag')){$exitReason='stop-requested';break}
    try{
      $hosts=@([GptWidgetSupervisorNative]::Hosts())
      $settings=$null;try{$settings=Get-Content -LiteralPath (Join-Path $info.DataDir 'settings.json') -Raw -Encoding UTF8|ConvertFrom-Json}catch{}
      $desktop=$settings -and $null-ne $settings.followHost -and !$settings.followHost
      $pause=$null;try{$pause=Get-Content -LiteralPath $pauseFile -Raw -Encoding UTF8|ConvertFrom-Json}catch{}
      $paused=Test-WidgetSupervisorPause $pause $hosts
      if($pause -and !$paused){Remove-Item -LiteralPath $pauseFile -ErrorAction SilentlyContinue}
      $visible=@($hosts|Where-Object{$_.visible})
      $visibleHostKey=Get-WidgetSupervisorHostKey $visible
      if($visibleHostKey-ne $lastVisibleHostKey){$nextLaunch=[DateTime]::MinValue;$lastVisibleHostKey=$visibleHostKey}
      $running=Get-WidgetSupervisorRunningGui $info.DataDir $info.AppDir
      $updateActive=Test-WidgetSupervisorUpdateActive $info
      # Retain the launch handle until startup finishes, so slow WPF startup
      # cannot create another GUI process before runtime.json is available.
      if($pendingGui -and ($running -or $pendingGui.HasExited)){$pendingGui.Dispose();$pendingGui=$null}
      if(Test-WidgetSupervisorShouldLaunch $paused ([bool]$desktop) $visible.Count $running ([bool]$pendingGui) $updateActive $nextLaunch ([DateTime]::UtcNow)){
        $starting=@(Get-WidgetSupervisorStartingGui $info.AppDir)
        if($starting.Count-gt 0){
          # Another instance or a previous supervisor is already starting the GUI.
          $nextLaunch=[DateTime]::UtcNow.AddSeconds(3)
        } else {
          $nextLaunch=[DateTime]::UtcNow.AddSeconds(10)
          $powerShell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
          $pendingGui=Start-Process -FilePath $powerShell -ArgumentList @('-NoLogo','-NoProfile','-STA','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"'+(Join-Path $info.AppDir 'runtime\start-widget.ps1')+'"'),'-WidgetPath',('"'+(Join-Path $info.AppDir 'widget.ps1')+'"')) -WindowStyle Hidden -PassThru
        }
      }
      if([DateTime]::UtcNow-ge $nextStatus){
        Write-WidgetSupervisorJson (Join-Path $info.DataDir 'supervisor-status.json') @{pid=$PID;processStartedAt=$processStartedAt;at=[DateTime]::UtcNow.ToString('o');mainWindows=$hosts.Count;visibleWindows=$visible.Count;paused=$paused;widgetRunning=$running;updateActive=$updateActive;taskName=$info.TaskName}
        $nextStatus=[DateTime]::UtcNow.AddSeconds(5)
      }
    }catch{
      # Keep one bounded diagnostic instead of an ever-growing log.
      $message=$_.Exception.Message
      if($message-ne $lastError){
        $lastError=$message
        try{[IO.File]::WriteAllText((Join-Path $info.DataDir 'supervisor-error.txt'),([DateTime]::UtcNow.ToString('o')+' '+$message),[Text.UTF8Encoding]::new($false))}catch{}
      }
    }
    Start-Sleep -Milliseconds 1500
  }
}catch{
  $exitMessage=$_.Exception.Message
  throw
}finally{
  if($pendingGui){$pendingGui.Dispose()}
  # supervisor-status.json is left as the last observed state; its timestamp
  # tells consumers that it is stale. The exit record names the exit reason.
  try{Write-WidgetSupervisorExitRecord $info.DataDir $exitReason $exitMessage $info.TaskName $processStartedAt}catch{}
  try{$mutex.ReleaseMutex()}catch{};$mutex.Dispose()
}
