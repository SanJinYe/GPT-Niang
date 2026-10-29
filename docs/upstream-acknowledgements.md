# 上游致谢与贡献记录

以下内容保留自上游 1.3.5 README，记录原项目的贡献与当时状态。本 fork 的当前功能及支持范围以[项目首页](../README.md)为准。

## 原项目贡献记录

以下按 GitHub 用户名排列，记录代码、方案、审查、问题复现与功能建议。感谢每一位参与者；已合并代码、待审方案和开放建议分别标明状态。

状态核对日期：2026-10-12。后续进展见对应 PR／Issue。

| 贡献者 | 具体贡献与关联 PR／Issue | 当前状态 |
| --- | --- | --- |
| [@Admilkk](https://github.com/Admilkk) | [PR #1](https://github.com/T7moris/GPT-Niang/pull/1)：动态额度展示、账号快照隔离、单实例刷新、进程恢复与安装／生命周期回归；[PR #16](https://github.com/T7moris/GPT-Niang/pull/16)：Windows 内置更新、校验、失败回滚和中断事务恢复，整合于 [PR #17](https://github.com/T7moris/GPT-Niang/pull/17)；[PR #20](https://github.com/T7moris/GPT-Niang/pull/20)：修复 Windows 拖动与定位时原生尺寸回写导致的持续放大，改为只移动窗口、由 WPF 管理尺寸，并补充窗口内／桌面模式及不同 DPI 的连续拖动回归；[PR #12 审查](https://github.com/T7moris/GPT-Niang/pull/12#pullrequestreview-5484203142)：指出个人额度的空分钟数会破坏 macOS 解码，并建议补充混合额度兼容测试。 | PR #1／#16／#20 已合并；PR #12 个人额度兼容审查已在 1.3.4 补齐 |
| [@AkihiM](https://github.com/AkihiM) | [PR #34](https://github.com/T7moris/GPT-Niang/pull/34)：Windows 图片图库、导入与撤销、缺失／损坏回退，以及小数音量恢复与相关测试。 | 图片与小数音量部分正在本地整合；其他改动待讨论 |
| [@FusaishiHaruaki-afk](https://github.com/FusaishiHaruaki-afk) | [PR #8](https://github.com/T7moris/GPT-Niang/pull/8)：真实 Go 账号的 30 天窗口复现、后端／Mac 适配及可选 `GPT_NIANG_SDK` 构建参数；[PR #9](https://github.com/T7moris/GPT-Niang/pull/9)：按窗口自身时长分类，覆盖槽位互换、月度边界与未知时长，并提供 Go 回归及 Swift 标题验证；相关实现与回归由 [PR #10](https://github.com/T7moris/GPT-Niang/pull/10) 整合。 | PR #8／#9 已合并；当前标签沿用整合后的精确时长显示 |
| [@gyb13451576](https://github.com/gyb13451576) | [Issue #11](https://github.com/T7moris/GPT-Niang/issues/11)：提供 v1.3.1 混合 DPI 双屏环境中重启 Codex 后窗口塌缩为 2×2 的复现、DPI 反馈循环分析、固定设计尺寸与 DIP／物理像素换算方案，以及自动测试和实际 HWND 采样验证；关联 [Issue #2](https://github.com/T7moris/GPT-Niang/issues/2)。 | 问题报告保持开放；PR #20 已合入拖动／定位的尺寸回写修复，重启后的 2×2 塌缩仍待验证 |
| [@Ifinty](https://github.com/Ifinty) | [PR #28](https://github.com/T7moris/GPT-Niang/pull/28)：角色图片高质量缩放。 | 已纳入 Windows 本地测试 |
| [@insightlacyrina](https://github.com/insightlacyrina) | [Issue #14](https://github.com/T7moris/GPT-Niang/issues/14)：建议增加可持久化的「双击角色打开设置」开关，保留其他设置入口，并提出 macOS 简体中文界面建议；描述了连续点击被设置窗口打断的场景。 | 1.3.4 按维护者最新要求取消双击设置；简／繁体与跟随系统选择已实现 |
| [@JCyxMio](https://github.com/JCyxMio) | [PR #12](https://github.com/T7moris/GPT-Niang/pull/12)：提出 Windows 多屏／混合 DPI 修复、Business `individualLimit` 个人额度显示，以及套餐标题、刷新按钮布局和命中修复；提供重复尺寸、额度解析及 WPF 验证。 | 方案整合于 1.3.4；DPI 定位以 PR #20 为准，并补齐 macOS 个人额度解码与显示 |
| [@maolilup](https://github.com/maolilup) | [PR #13](https://github.com/T7moris/GPT-Niang/pull/13)：针对 [Issue #2](https://github.com/T7moris/GPT-Niang/issues/2)，提出使用固定设计宽高计算跟随／拖动尺寸以避免 DPI 尺寸漂移，并提供不同设计画布、缩放与目标 DPI 下的连续原生尺寸回归。 | 固定设计尺寸与回归已适配到 1.3.4；原生调用保持只移动 |
| [@meaqua9420](https://github.com/meaqua9420) | [PR #3](https://github.com/T7moris/GPT-Niang/pull/3)：SwiftUI／AppKit 原生 macOS 挂件、原有气泡／动画／配色／音效移植、窗口跟随与原生点击设置、菜单栏和可选登录启动；新增只读本地聊天速度面板、Mac CLI 与 worker 锁支持、应用构建及双平台 CI。 | 已合并 |
| [@ShiroasabaMio](https://github.com/ShiroasabaMio) | [Issue #2](https://github.com/T7moris/GPT-Niang/issues/2)：报告 v1.2.3 跨不同 DPI 显示器移动时挂件放大、跳动与错位，提供 120／144 DPI 复现、尺寸反馈循环分析、固定设计尺寸与统一 DPI 上下文建议及本机修复结果。 | 问题报告保持开放；PR #20 已合入拖动修复，跨屏场景继续验证，其他方案见 PR #12／#13 |
| [@T7moris](https://github.com/T7moris) | 项目创作、维护、集成与发布。[PR #5](https://github.com/T7moris/GPT-Niang/pull/5)：Mac 跟随采样、限频与多窗口选择；[PR #6](https://github.com/T7moris/GPT-Niang/pull/6)：1.3.0 双平台安装包、版本与发布校验；[PR #7](https://github.com/T7moris/GPT-Niang/pull/7)：下载、安装、退出、迁移和卸载说明；[PR #10](https://github.com/T7moris/GPT-Niang/pull/10)：套餐自动识别与动态额度整合；[PR #17](https://github.com/T7moris/GPT-Niang/pull/17)：双平台内置更新、自动清理和 Mac 原生回退；[PR #18](https://github.com/T7moris/GPT-Niang/pull/18)：MIT 代码许可、素材使用边界及文档名称统一；[PR #21](https://github.com/T7moris/GPT-Niang/pull/21)：以 PR #20 为准整合 DPI、Business 个人额度、原生 Mac 交互与语言，补齐回归、旧偏好迁移和 1.3.4 双平台发布。 | 前述维护与整合 PR 已合并；PR #21 为 1.3.4 的统一整合 |
| [@TheRuabit](https://github.com/TheRuabit) | [PR #4](https://github.com/T7moris/GPT-Niang/pull/4)：安装器直接按 UTF-8 解码插件列表 JSON，避免 Windows 默认编码造成中文安装路径乱码。 | 已合并 |
| [@wzc20090621-gif](https://github.com/wzc20090621-gif) | [PR #15](https://github.com/T7moris/GPT-Niang/pull/15)：Windows 独立桌面模式、跨屏拖动和两种模式的位置保存，解除主窗口归属／裁切并支持桌面置顶；增加本机管道额度通信与文件队列回退，修复安装后的 Node／MCP 绝对路径配置。 | 已合并 |

| [@ytzha](https://github.com/ytzha) | [PR #29](https://github.com/T7moris/GPT-Niang/pull/29)：改用系统 WAV 播放器，保留按下／松开顺序与音量缩放。 | 正在 Windows 本机测试；补充资源清理与连续点击检查 |

本次完整致谢记录由 [@T7moris](https://github.com/T7moris) 在 [PR #19](https://github.com/T7moris/GPT-Niang/pull/19) 中补充。

交互参考 [@MeteorNOX](https://github.com/MeteorNOX) 的 [DeepSeek-Balance-Whale-Widget](https://github.com/MeteorNOX/DeepSeek-Balance-Whale-Widget)，感谢其公开的交互参考与 7 句上游语录来源。Windows WPF 与 Mac 原生界面分别实现，语录包含原创、用户提供及上游文本，来源和 MIT 许可见 [语录许可](../gpt-niang-usage/assets/quotes-LICENSE.txt)。使用合成提示音，没有打包 DSH 原角色、动图或音效。具体对照见 [功能对照](../gpt-niang-usage/DSH功能对照.md)。

