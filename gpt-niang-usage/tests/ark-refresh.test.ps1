$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $root 'runtime/dual-quota.ps1'),[Text.Encoding]::UTF8)))
$now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
Set-ArkQuotaSnapshot @{status='refresh_in_progress'} $now
if(!$script:arkStatus.pending -or $script:arkStatus.error){throw 'Initial concurrent refresh reported failure'}
$good=@{status='ok';observed_at=[DateTimeOffset]::UtcNow.ToString('o');windows=@(@{window='session';used_percent=20;remaining_percent=80},@{window='weekly';used_percent=40;remaining_percent=60})}
Set-ArkQuotaSnapshot $good $now
Set-ArkQuotaSnapshot @{status='refresh_in_progress'} $now
if(!$script:arkStatus.queryOk -or $script:arkStatus.windows[0].remaining-ne 80){throw 'Concurrent refresh discarded good quota'}
Set-ArkQuotaSnapshot $good $now
if($script:arkStatus.pending){throw 'Successful refresh retained pending status'}
Set-ArkQuotaSnapshot @{status='refresh_in_progress'} $now
Set-ArkQuotaSnapshot @{status='refresh_in_progress'} ($now+59999)
if(!$script:arkStatus.pending){throw 'Concurrent refresh timed out early'}
Set-ArkQuotaSnapshot @{status='refresh_in_progress'} ($now+60000)
if($script:arkStatus.pending-or $script:arkStatus.queryOk-or !$script:arkStatus.error){throw 'Stale refresh lock remained pending forever'}
Set-ArkQuotaSnapshot @{status='refresh_in_progress'} ($now+120000)
if($script:arkStatus.pending){throw 'Repeated stale lock reset the waiting deadline'}
Set-ArkQuotaSnapshot $good ($now+120001)
if(!$script:arkStatus.queryOk-or $null-ne $script:arkPendingSince){throw 'Successful query failed to recover after timeout'}
$failed=$false
try{Set-ArkQuotaSnapshot @{status='auth_required'} $now}catch{$failed=$true}
if(!$failed){throw 'Authentication failure was hidden'}
Write-Output 'PASS: pending refresh, preserved fresh data, recovery, real authentication failure'
