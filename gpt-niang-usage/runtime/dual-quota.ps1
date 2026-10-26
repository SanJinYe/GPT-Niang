$script:arkStatus=$null
$script:arkProcess=$null
$script:arkNextRead=0L
$script:arkReadStarted=0L
$script:arkReadTask=$null
$script:arkErrorTask=$null
function Convert-ArkQuota($Snapshot) {
  if($Snapshot.status-ne 'ok'){throw ('Ark '+$Snapshot.status)}
  $observed=[DateTimeOffset]::Parse([string]$Snapshot.observed_at).ToUnixTimeMilliseconds()
  $windows=@()
  foreach($kind in @('session','weekly')){
    $matches=@($Snapshot.windows|Where-Object{$_.window-eq $kind})
    if($matches.Count-ne 1){throw ('Ark 窗口缺失或重复：'+$kind)}
    $q=$matches[0]
    if($null-eq $q.used_percent -or $null-eq $q.remaining_percent){throw 'Ark 百分比缺失'}
    $used=[double]$q.used_percent;$left=[double]$q.remaining_percent
    if([double]::IsNaN($used)-or [double]::IsNaN($left)-or $used-lt 0-or $used-gt 100-or $left-lt 0-or $left-gt 100-or [Math]::Abs($used+$left-100)-gt .01){throw 'Ark 百分比无效'}
    $reset=if($q.reset_at){[DateTimeOffset]::Parse([string]$q.reset_at).ToUnixTimeSeconds()}else{$null}
    $windows+=@{minutes=if($kind-eq 'session'){300}else{10080};used=$used;remaining=$left;resetsAt=$reset}
  }
  return @{queryOk=$true;windows=$windows;observedAt=$observed;error=$null}
}
function Stop-ArkQuotaRead {
  if($script:arkProcess){
    if(!$script:arkProcess.HasExited){$script:arkProcess.Kill()}
    $script:arkProcess.Dispose();$script:arkProcess=$null
  }
}
function Set-ArkQuotaSnapshot($Snapshot,[long]$Now) {
  if($Snapshot.status-eq 'refresh_in_progress'){
    if(!$script:arkStatus -or !$script:arkStatus.queryOk){$script:arkStatus=@{queryOk=$false;error=$null;pending=$true}}
    else{$script:arkStatus.pending=$true}
    $script:arkNextRead=$Now+5000
    return
  }
  $script:arkStatus=Convert-ArkQuota $Snapshot
  $script:arkNextRead=$Now+60000
}
function Write-ArkDisplayStatus {
  $diagnostic=@{at=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();status=$script:arkStatus;nextRead=$script:arkNextRead}
  [IO.File]::WriteAllText((Join-Path $script:dataDir 'ark-display-status.json'),($diagnostic|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
}
function Update-ArkQuotaRead {
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  if($script:arkProcess){
    if(!$script:arkProcess.HasExited){
      if($now-$script:arkReadStarted-gt 60000){Stop-ArkQuotaRead;$script:arkStatus=@{queryOk=$false;error='Ark 查询超时'};$script:arkNextRead=$now+60000}
      return
    }
    try{
      if($script:arkProcess.ExitCode-ne 0){throw 'Ark 查询失败'}
      Set-ArkQuotaSnapshot ($script:arkReadTask.Result | ConvertFrom-Json) $now
    }catch{$script:arkStatus=@{queryOk=$false;error=$_.Exception.Message};$script:arkNextRead=$now+60000}
    finally{Stop-ArkQuotaRead;$script:arkReadTask=$null;$script:arkErrorTask=$null}
    Write-ArkDisplayStatus
  }
  if($now-lt $script:arkNextRead -or !$script:window.IsVisible){return}
  try{
    $connection=[IO.File]::ReadAllText((Join-Path $script:dataDir 'ark-connection.json'))|ConvertFrom-Json
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$connection.pythonPath;$start.Arguments='"'+$connection.handoffPath+'" usage'
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.StandardOutputEncoding=[Text.Encoding]::UTF8;$start.StandardErrorEncoding=[Text.Encoding]::UTF8
    $start.EnvironmentVariables['PYTHONIOENCODING']='utf-8'
    $script:arkProcess=[Diagnostics.Process]::Start($start)
    $script:arkReadTask=$script:arkProcess.StandardOutput.ReadToEndAsync()
    $script:arkErrorTask=$script:arkProcess.StandardError.ReadToEndAsync()
    $script:arkReadStarted=$now
  }catch{$script:arkStatus=@{queryOk=$false;error=$_.Exception.Message};$script:arkNextRead=$now+60000;Stop-ArkQuotaRead;Write-ArkDisplayStatus}
}
function Get-AllQuotaRows {
  foreach($row in (Get-QuotaRows)){
    $row.provider='Codex';$row.hidden=($row.prefix-eq 'Short');$row.queryOk=$false;$row.barWidth=184
    $row.error=if(!$script:status){'正在读取…'}elseif($script:status.queryOk){'未提供此窗口'}else{'额度读取异常'}
    $row
  }
  $fresh=$script:arkStatus.observedAt -and ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$script:arkStatus.observedAt)-lt 180000
  foreach($spec in @(@{prefix='ArkShort';minutes=300;label='5 小时'},@{prefix='ArkWeek';minutes=10080;label='每周'})){
    $q=$null
    if($script:arkStatus.queryOk -and $fresh){$q=@($script:arkStatus.windows|Where-Object{$_.minutes-eq $spec.minutes})[0]}
    $error=if(!$script:arkStatus){'正在读取…'}elseif($script:arkStatus.pending){'正在刷新…'}elseif(!$script:arkStatus.queryOk){'读取失败'}elseif(!$fresh){'数据已过期'}else{'暂无数据'}
    @{prefix=$spec.prefix;window=$q;label=$spec.label;provider='Ark';queryOk=$false;error=$error;barWidth=184}
  }
}
