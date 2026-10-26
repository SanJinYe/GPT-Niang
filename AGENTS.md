# GPT-Niang 项目约定

- 本目录是定制功能的源码工作区；修改先落在仓库，再按任务部署到安装目录。不要只改已安装副本。
- 上游是 `T7moris/GPT-Niang`（remote: upstream），个人 fork 是 `SanJinYe/GPT-Niang`（remote: origin）。
- 当前本地迁移分支为 `feature/local-companion-customizations`。迁移状态及发布前缺口见 `docs/local-customizations.md`。
- Windows 挂件入口是 `gpt-niang-usage/widget.ps1`、`widget.xaml`；新增运行模块在 `runtime/`，验证在 `tests/`。
- 网易云桥接源码在 `integrations/netease-desktop-mcp/`；保留其独立 LICENSE、THIRD_PARTY_NOTICES 与 UPSTREAM.json。
- `.local/` 保存本机参考与核验记录，不入库；连接配置、账户快照、歌词缓存、认证信息与运行日志不提交。
- 原挂件图片适用 `assets/CHARACTER-NOTICE.txt`，不能按代码 MIT 许可解释。候选图集见 `docs/character-sources.md`，尚未接入产品。
- Windows PowerShell 5.1 直接读取无 BOM 中文脚本可能产生乱码；沿用入口的显式 UTF-8 加载方式，不为规避此问题增加 BOM。
- 新增额度与音乐能力目前只做了 Windows 验证，不把 macOS 标记为已支持。
