# Windows 定制集成

安装文件清单包含 Windows 新增运行模块；音乐桥接、Ark 外部工具及登录由使用者单独配置。macOS 尚未实现这些定制。

## Ark 额度

依赖一个支持 `usage` 命令的 `opencode-ark-handoff/handoff.py` 安装，以及同一账户的官方 Ark CLI 控制面登录。该外部工具不随本仓库分发。查询只读取套餐，不调用模型。

在挂件数据目录（默认 `%USERPROFILE%/.gpt-niang/state`）创建 `ark-connection.json`，用实际路径替换示例：

```json
{
  "pythonPath": "C:\\Path\\To\\python.exe",
  "handoffPath": "C:\\Path\\To\\opencode-ark-handoff\\handoff.py"
}
```

挂件可见时约每分钟查询一次。刷新占用显示“正在刷新”，保留仍有效的结果；读取失败和过期不会伪装成 0%。Codex 页按本 fork 的偏好隐藏 5 小时窗口，Ark 页保留 5 小时与每周窗口。

## 网易云与歌词

源码在 `integrations/netease-desktop-mcp/`，来自其中 `UPSTREAM.json` 记录的上游，保留独立 MIT 许可与第三方来源说明。

1. 在该目录运行 `npm ci --ignore-scripts`。需要 Node.js 24 或更高版本。
2. 按该集成的 README 启动网易云本机控制通道。当前桥接默认播放器为 `C:\Program Files\NetEase\CloudMusic\cloudmusic.exe`，端口为 `9223`；原上游启动脚本的默认端口为 9229，因此运行时需明确传入 `-Port 9223`。本地控制接口只绑定 `127.0.0.1`。
3. 在同一挂件数据目录创建 `music-connection.json`，替换实际路径：

```json
{
  "nodePath": "C:\\Program Files\\nodejs\\node.exe",
  "bridgePath": "C:\\Path\\To\\GPT-Niang\\integrations\\netease-desktop-mcp\\widget-bridge.mjs"
}
```

该配置连接挂件与桥接程序；聊天客户端使用 MCP 的配置另见集成 README。无需把个人聊天客户端配置放入仓库。测试过的网易云版本为 Windows 3.1.42.205594；更新后界面字段可能变化，识别失败会返回未知状态。

角色或气泡依次显示 Codex、按添加顺序启用的额度来源、台词／歌词，然后收起。播放时台词页显示当前歌词并常驻，再点可收起；具体点击次数取决于启用来源数量。暂停后恢复限时台词。歌词从网易云接口读取，不写入完整歌词文件；桥接状态只保存当前行。灯效、左右移动可单独关闭。QQ 音乐和 Spotify 也使用同一桥接程序，通过 Windows 媒体会话识别，不要求为它们开启网易云控制通道。

当前配置仍是手动接入，不能把 fork 源码直接当成已经整合全部外部依赖的一键发行包。本机连接配置、状态、认证信息及依赖安装目录均不提交。
