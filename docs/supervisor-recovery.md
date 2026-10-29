# 守护进程恢复策略

本文说明 Windows 挂件守护进程在启动项、计划任务和更新事务之间如何恢复。实现位于
`runtime/supervisor-task.ps1`、`runtime/supervisor.ps1` 和 `runtime/start-supervisor.ps1`。

## 计划任务策略

新安装使用一个操作（`wscript.exe` 启动稳定入口）和两个触发器：

- 登录触发器：沿用原来的当前用户登录启动。
- 恢复触发器：`Once` 起始时间加每分钟一次、无结束时间的重复；用于守护进程被外部终止后，
  在同一登录会话内重新拉起。
- 设置：`IgnoreNew`、无限执行时间、`StartWhenAvailable`、`RestartCount=3`、
  `RestartInterval=1 分钟`。
- 身份：任务名仍为 `GPT Niang Usage - <SID>`，主体为当前用户 `Interactive` + `Limited`，
  操作路径仍受安装身份和 `binding.json` 校验。

`IgnoreNew` 只允许一个任务实例；守护进程本身的命名互斥量和 `runtime.json` 的 PID／启动时间
校验继续防止重复 GUI。`RestartCount` 只是任务失败后的附加重试，不是恢复的主力；被外部
`Stop-Process` 或进程树清理后，任务会回到 Ready，由每分钟触发器重新启动。

## 旧任务迁移

旧任务通常只有登录触发器，且 `RestartCount=0`。`Register-WidgetSupervisorTask` 现在会比较：

- 操作路径（旧版 `supervisor.vbs` 或稳定入口）；
- 两个触发器的类型、登录用户和一分钟重复策略；
- `IgnoreNew`、无限执行时间、`RestartCount=3`、`RestartInterval=1 分钟` 和
  `StartWhenAvailable`。

只有确实不一致时才停止并替换任务；一致时重复调用不会停止正在运行的守护进程。旧任务在
升级安装时的 `Install.ps1`，或用户下一次通过 `start-supervisor.ps1` 启动挂件时完成迁移。

如果注册发生在计划任务自己的进程里（`update-agent.ps1 -Supervisor` 的事务恢复），代码会
跳过停止、重注册和重复启动：这些动作可能终止正在修复安装的自身实例。此时会把原因写入
`supervisor-task-pending.json`，由下一次正常安装或启动完成迁移。`Stop-WidgetSupervisorTask`
同样识别自身入口，不会对自身调用 `Stop-ScheduledTask`。

## 用户状态与更新事务

周期触发只执行 `update-agent.ps1 -Supervisor` → `supervisor.ps1`，不会调用
`Resume-WidgetSupervisor`，因此不会清除以下状态：

- `supervisor-disabled.flag`：守护进程直接退出；
- `supervisor-stop.flag`：守护进程直接退出（通常来自更新或停用）；
- `supervisor-pause.json`：暂停跟随当前宿主；桌面暂停持续有效。

显式安装或用户主动启动（`Install.ps1`、`start-supervisor.ps1`）才会恢复这些状态。

更新事务期间，`update-installing.json` 或事务阶段为 `stopping`、`moving-old`、`moving-new`、
`registering`、`registering-old`、`restoring` 时，守护进程继续写心跳但不会启动 GUI；事务
结束并删除安装标记后恢复。这样既不会干扰更新健康检查，也不会在文件替换期间打开混合版本
的挂件。`start-supervisor.ps1` 在同样条件下直接返回，不清除暂停／停止／禁用状态，也不迁移
或启动任务，避免与更新事务争用安装目录。损坏的事务文件会明确报错并暂停启动，避免把半更新的安装当成安全状态；需检查更新诊断后恢复。

## GUI 归属与重复启动

启动前同时检查：

- 命名互斥量（同一用户仅一个守护进程）；
- 计划任务 `IgnoreNew`；
- `runtime.json` 中的窗口句柄、PID、进程启动时间和 `widget.ps1` 命令行；
- 正在运行的 `start-widget.ps1` 启动进程（覆盖 `runtime.json` 尚未写入的慢启动窗口）。

PID 重用由进程启动时间拒绝。宿主窗口变化使用窗口句柄、PID 和启动时间组成的主机键；新宿主
或重新打开的宿主会重置启动退避并恢复挂件。

## 退出诊断

- `supervisor-status.json`：最后一次心跳（PID、启动时间、可见窗口数、暂停／更新状态等），
  退出后保留，读取方应以时间戳判断是否过期。
- `supervisor-exit.json`：最近一次正常退出的 PID、启动时间、时间、原因（`disabled`、
  `stop-requested`、`fatal`）和任务名；致命信息最多 500 字符，不包含聊天或密钥。
- `supervisor-error.txt`：循环内最近一条不同的错误，带 UTC 时间，不持续追加日志。

被 `Stop-Process`、进程树清理或断电强杀时无法写退出事件；此时 `supervisor-exit.json`
不存在或仍是上一次退出的记录，应与 `supervisor-status.json` 的时间戳／PID 对照，不能把
缺失或过期记录解释为本次正常退出。

## 部署与迁移步骤

1. 按正常发布流程更新源码并部署到安装目录；不要在运行中的安装目录手工替换单个文件。
2. `Install.ps1` 会调用 `Install-WidgetUpdateAgent`，把新的 `supervisor-task.ps1` 等模块同步到
   `%LOCALAPPDATA%\GPTNiangUsage\update-agent`。核对两份文件哈希一致。
3. 让已注册任务完成策略迁移：以当前用户运行一次新版本的 `runtime\start-supervisor.ps1`，
   或通过启动项打开挂件。该路径会在检测到旧策略时安全替换任务；若守护进程正在运行，只会
   短暂重启守护进程，不关闭挂件窗口。
4. 核对任务：

```powershell
$name='GPT Niang Usage - '+[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$task=Get-ScheduledTask -TaskName $name
$task.Triggers | Format-List
$task.Settings | Select-Object MultipleInstances,ExecutionTimeLimit,RestartCount,RestartInterval,StartWhenAvailable
```

应看到一个登录触发器和一个一分钟重复的时间触发器，且 `MultipleInstances=IgnoreNew`、
`ExecutionTimeLimit=PT0S`、`RestartCount=3`、`RestartInterval=PT1M`。

## 验证范围

自动测试 `tests/supervisor.test.ps1` 覆盖策略检查、旧任务升级、幂等、自身事务恢复、暂停／
禁用／停止标记、单实例、GUI 归属、宿主替换键和更新期间抑制启动；已加入
`tests/run-windows-tests.ps1`。测试只使用临时目录、模拟任务对象和隔离命名互斥量，不读取或
修改真实安装与真实计划任务。

## 本机验证（2026-10-29）

Codex 接管未完成的方舟工作后，修正了实际任务定义中默认开启的
`StopAtDurationEnd`，并将其显式设为 `false`。损坏的更新事务文件改为明确报错，
不再当作“没有更新”继续启动。

已完成：

- Windows PowerShell 5.1：守护 84 条、安装 42 条、生命周期 7 条、更新器 48 条断言通过。
- PowerShell 7：上述四组同样通过；16 个关键界面测试文件通过。
- 完整 WPF 启动：默认角色和替代角色均通过；测试改为按安装清单复制依赖，避免漏掉新增模块。
- 测试入口修复作用域：每例仍在独立进程运行，顶层 fixture 与函数的 `$script:` 引用一致。
- 宿主识别 27 项与窗口层级测试通过，包含当前真实 Codex 宿主识别。
- 已更新安装目录的三个运行模块、稳定入口的 `supervisor-task.ps1`，并迁移实际计划任务。
- 在计划任务环境中同时强制结束真实挂件和守护进程；外部任务 **19.5 秒**后拉起新进程，
  新心跳确认挂件可见、跟随就绪。重复手动启动不改变进程、不创建重复实例。

恢复触发器每分钟运行一次，实际恢复耗时还包含系统调度及启动时间；19.5 秒是本次观测值，
不是固定时限。用户主动暂停、禁用和停止标记由隔离测试验证。

额外的 `host-occlusion.test.ps1` 在当前机器上未通过“外部窗口完全遮挡”检查；
使用本次修改前的测试入口复测也同样失败，相关产品源码未改动，不将该项记为通过。
本次未关闭用户的 Codex，也未执行一次真实 Codex 升级；升级后窗口重新识别由宿主身份测试、
宿主替换键测试及真实进程恢复共同覆盖，不能等同于完成所有未来版本的升级验证。

本次故障前任务只在登录时触发且没有失败重试，这是未能自动恢复的确定缺口。
当时未启用计划任务历史，缺少对应崩溃记录，仍无法确定最初由哪个进程结束了挂件与守护。
