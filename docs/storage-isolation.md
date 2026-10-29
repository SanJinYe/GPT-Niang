# Windows 配置分叉：原因与修复

## 问题描述

挂件从 Codex 工具会话直接启动时，Ark 配置和轮播正常；改由 Windows 计划任务启动后，
第二次点击直接进入台词。设置里的 OpenCode 本机 token 统计仍存在，因为它不依赖 Ark 的连接文件。
当时的状态文件检查也出现异常：工具会话读到旧心跳，而计划任务环境里的心跳持续刷新。

这不是 Ark API 故障，也不是 JSON 路径拼写错误。两种环境访问同一个逻辑 AppData 路径时，
打开了不同的物理文件。

## 根因证据

对当前工具进程打开的 `providers.json` 调用 Windows `GetFinalPathNameByHandleW`，结果指向：

```text
%LOCALAPPDATA%\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\GPTNiangUsage\state\providers.json
```

而计划任务中的独立进程使用：

```text
%LOCALAPPDATA%\GPTNiangUsage\state\providers.json
```

前者有旧的来源配置和连接文件，后者最初没有。此前说“读取到旧状态”描述的是现象，
不是普通缓存问题。根因是 **MSIX AppData 文件虚拟化**：带包身份的进程优先读取包内私有副本，
包外进程读取普通 AppData，路径字符串相同并不意味着同一文件。

机制见 [微软：打包桌面应用的文件系统行为](https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-behind-the-scenes#appdata-operations-on-windows-10-version-1903-and-later)。
Codex 更新是否直接终止了之前的进程仍无确证；启动方式切换暴露了已经存在的两份配置。

## 修复

默认持久化位置改为用户目录下、不位于 AppData 的共享路径：

- 状态与设置：`%USERPROFILE%\.gpt-niang\state`
- 稳定启动与更新入口：`%USERPROFILE%\.gpt-niang\update-agent`

安装配置、计划任务、登录快捷方式和更新器统一使用这套位置；Node 更新器尊重安装配置中的
`updateAgent`，不再另行拼接旧 AppData 路径。新安装直接采用新默认值。

既有安装必须完成迁移后再启动新版本，不能仅替换启动模块而留下旧 `installation.json`。
迁移入口：

```powershell
pwsh.exe -NoProfile -File .\gpt-niang-usage\runtime\migrate-storage.ps1 -AppDir <实际安装目录> -LegacyOverlay <旧包内state目录>
```

迁移必须在包外 Windows 进程执行；在包内启动会明确拒绝，避免再次读到合并视图。
`LegacyOverlay` 可省略；指定时只读取该目录的挂件偏好和素材，不读取其他应用资料。

迁移规则：

- 核对安装和任务身份，拒绝未完成的更新事务、链接路径和已占用的目标目录。
- 停止旧实例后复制持久化设置；当前普通目录优先，缺失文件从旧包内目录补回。
- 保留当前来源顺序及启用状态，只补回缺失的加密密钥字段，不解密或输出密钥。
- 不复制旧 PID、心跳、锁、停止标记及歌词／查询缓存。
- 保留旧数据，备份程序模块、安装配置、任务及登录快捷方式；切换失败会尝试恢复旧入口，
  并明确报告失败及备份位置。
- 迁移已完成时再次执行不会覆盖设置。

旧目录只是保留的备份，后续修改应以安装配置所指向的新目录为准。

## 本机验收（2026-10-29）

- 文件句柄确认工具会话中的新配置实际位于 `.gpt-niang/state/providers.json`，不再指向包内目录。
- 工具进程写入探针，包外计划任务能读取；计划任务写回字段，工具进程也能立即读到。
- 两侧读取的 providers 文件 SHA-256 相同；重复迁移未改动配置。
- 实际计划任务与登录入口已改指向 `.gpt-niang/update-agent`，源码与安装目录对应模块逐一一致。
- 同时强制结束挂件与守护进程后，14.3 秒恢复新实例，挂件可见且窗口跟随就绪。
- 重启后 Ark 5 小时和每周额度正常，连接不再依赖 Codex 包内副本。
- Node：148 项通过、1 项跳过；更新器专项 23 项通过。
- Windows：存储迁移测试、守护、安装、更新及完整 WPF 启动验证通过；覆盖原生优先、
  缺失连接补回、密钥密文保留、排除旧锁和状态、损坏配置明确失败。

这是对当前包内／包外文件分叉机制的修复，不代表磁盘故障、手动删除或未来系统行为改变时
配置永远不会丢失。备份保留在 `.gpt-niang/migration-backup-*` 和原数据目录。
