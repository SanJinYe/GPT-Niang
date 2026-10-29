# 审查修复与验证（2026-10-28）

- 更新渠道固定为 `SanJinYe/GPT-Niang`，拒绝原作者仓库的发布地址；fork 暂无 Release 时明确显示暂无正式版，不使用上游兜底。
- 设置浮窗允许发起手动检查更新；安装阶段仍等待编辑窗口关闭。更新状态保留在浮窗中并实时刷新。
- 提起图大于可用区域时，超出尺寸的轴以鼠标位置判定吸附，内部位置不再强制贴边；普通尺寸仍按图像边界判断，保留原防抖。
- 设置控件绑定原始标题，音效导入／清除后的名称及更新状态能够同步。
- Windows 环境变量兼容模式按大小写不敏感方式读取；直接粘贴密钥的加密保存与管道传递不变。

统一 Windows 入口保留原有用例，并加入实时吸附、提起、额度、设置和本次修复测试；每个文件在独立进程中显式按 UTF-8 加载，保留脚本路径。可列出或选择用例：

```powershell
pwsh.exe -NoProfile -File gpt-niang-usage/tests/run-windows-tests.ps1 -List
pwsh.exe -NoProfile -STA -File gpt-niang-usage/tests/run-windows-tests.ps1 -TestNames review-fixes,live-docking,settings-window,settings-menu,provider-background,provider-cycle,credit-layout,drag-pickup,pickup-dock-release,pickup-overlays,dock-poses,dock-animation,music-dock-release,ark-refresh,lyrics-scene,quota-page-cycle
```

不指定筛选时运行全部注册用例。默认继承调用入口的 PowerShell 宿主，也可用 `-PowerShellExecutable` 明确指定。`run-windows-case.ps1` 负责 UTF-8 与每文件隔离；音乐类型加载兼容 PowerShell 7 的引用程序集。

本轮实际验证：Node 148 通过、1 跳过；以上 16 个 Windows 测试文件通过。默认入口共注册 75 个文件，本轮未宣称执行全部 75 个。更新渠道只读请求返回 fork 暂无 Release（404），未下载或安装任何远端包。
