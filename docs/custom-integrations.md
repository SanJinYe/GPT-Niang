# Windows 定制集成

这些功能按“律动开关 → 多额度 → 网易云与歌词”三个提交组织。安装文件清单包含新增运行模块；外部工具及登录由使用者单独配置。macOS 尚未实现这些定制。

## Ark 额度

依赖一个支持 `usage` 命令的 `opencode-ark-handoff/handoff.py` 安装，以及同一账户的官方 Ark CLI 控制面登录。该外部工具不随本仓库分发。查询只读取套餐，不调用模型。

在挂件数据目录（默认 `%LOCALAPPDATA%/GPTNiangUsage/state`）创建 `ark-connection.json`，用实际路径替换示例：

```json
{
  "pythonPath": "C:\\Path\\To\\python.exe",
  "handoffPath": "C:\\Path\\To\\opencode-ark-handoff\\handoff.py"
}
```

挂件可见时约每分钟查询一次。刷新占用显示“正在刷新”，保留仍有效的结果；读取失败和过期不会伪装成 0%。Codex 页按本 fork 的偏好隐藏 5 小时窗口，Ark 页保留 5 小时与每周窗口。
