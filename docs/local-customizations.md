# 本地定制迁移记录

本项目从临时聊天工作区迁入正式 Git 仓库，迁移日期为 2026-10-25（America/Los_Angeles）。

- 原作者：<https://github.com/T7moris/GPT-Niang>
- 个人 fork：<https://github.com/SanJinYe/GPT-Niang>
- 迁移基线：`b6f5eb8972d1802821006b7208d20a834fa6a08b`，分支 `feature/local-companion-customizations`。
- 基线的 widget、music、ui-settings 核心文件与本次聊天最初保留的未修改文件一致。
- 已安装程序仍从 `%LOCALAPPDATA%/Programs/GPTNiangUsage` 运行，本次迁移没有切换或重装运行副本。
- 定制按“律动开关、多额度、网易云与歌词”三个提交维护在功能分支；外部依赖仍需手动配置，见 `custom-integrations.md`。

## 已迁入的行为

1. 点击角色或气泡：Codex → Ark → 预设语句／播放中歌词 → 收起。Codex 页只显示每周额度；Ark 显示 5 小时与每周额度，百分比字号为 20。
2. Ark 使用现有官方 CLI 额度读取封装，不调用模型；处理刷新占用、未知、失败和过期状态。
3. 网易云桌面 MCP 识别当前歌曲及播放状态；本地音频分析负责节拍。可选择跟随播放或手动律动，灯效与左右移动分别开关并保存。
4. 歌词按实际歌曲 ID 和播放进度匹配当前行，第三页常驻；暂停后恢复预设语句，用户可主动收起。缺失或失效不沿用上一首歌词。
5. 保留原始角色素材及来源声明。参考素材研究没有替换运行中的形象。

## 文件与外部依赖

| 功能 | 主要入口 |
|---|---|
| 额度页与点击轮转 | `gpt-niang-usage/widget.ps1`、`widget.xaml` |
| Ark 额度 | `runtime/dual-quota.ps1`，运行时读取数据目录的 `ark-connection.json` |
| 音乐与独立开关 | `runtime/music.ps1`、`runtime/music-visual.cs`、`runtime/ui-settings.ps1` |
| 常驻歌词 | `runtime/lyrics.ps1`、`runtime/quote-layout.ps1` |
| 网易云 MCP 与桥接 | `integrations/netease-desktop-mcp/`，运行时读取 `music-connection.json` |

两个连接配置由本机维护，均被 Git 忽略。Ark 的 `handoff.py` 属于外部工具，不在此仓库中；网易云需要本地回环控制通道。未复制本机安装配置、账户状态、用户语录、完整歌词、认证材料或 node_modules。

## 提交划分与后续发布事项

- **独立 UI 改动**：灯效开关、左右移动开关、设置持久化及测试，适合优先整理为小提交。
- **多提供方额度**：把 Ark 外部命令配置变成可选集成，保留未安装／未登录提示；当前隐藏 Codex 5h 是个人偏好，提交上游时宜提供可配置行为。
- **网易云与歌词**：独立说明第三方 MCP 依赖、端口与播放器兼容版本，完善安装配置和失败恢复。
- **位置形象**：先确定采用的角色图集、使用范围与位置映射，再接入，避免先把不匹配的表情包装进安装包。

新增模块已纳入安装文件清单。发布前仍有以下限制：桥接程序保留本机验证时的默认播放器路径／端口；部分测试依赖真实本机登录或播放器；macOS 尚未实现新增能力。源码提交不代表已经完成可分发安装包的整合。

## 验证

离线逻辑与 Windows 渲染测试可分别运行：

```powershell
powershell.exe -NoProfile -STA -File gpt-niang-usage/tests/ark-refresh.test.ps1
powershell.exe -NoProfile -STA -File gpt-niang-usage/tests/lyrics-scene.test.ps1
powershell.exe -NoProfile -STA -File gpt-niang-usage/tests/quota-page-cycle.test.ps1
powershell.exe -NoProfile -STA -File gpt-niang-usage/tests/music-horizontal.test.ps1
```

网易云集成：在 `integrations/netease-desktop-mcp` 执行 `npm ci --ignore-scripts`、`npm test`。

`dual-quota.test.ps1` 是本机额度集成检查，会访问真实只读额度接口；不要当作无认证 CI 测试。迁移时的逐文件核验保存在忽略目录 `.local/migration-verification.json`。

迁移后验证：上述四个挂件测试脚本全部通过；网易云集成的 58 项测试全部通过；`git diff --check` 无错误。八个挂件源码文件与正在使用的安装副本逐字节一致。
