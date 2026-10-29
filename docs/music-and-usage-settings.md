# 音乐与用量设置（Windows）

右键 →「设置」，默认进入「用量」。设置窗口为可拖动的圆角无边框浮卡，右上角关闭或 Esc 收起。人物点击顺序为 Codex → 按添加顺序启用的来源 → 歌词／台词 → 收起；没有来源时 Codex 后直接显示台词。禁用的来源跳过，重新启用的来源追加到末尾。旧 Ark 连接自动迁移为首个来源。Codex 5 小时额度继续隐藏。

气泡直接显示每个来源的数据，不再显示“打开用量查询”中间页。查询在设置窗口关闭时仍可完成，查询中暂缓收起，完成后恢复 5 秒显示。失败、过期及未配置状态不会显示成 0。

OpenRouter 的 `/api/v1/credits` 使用管理密钥，`/api/v1/key` 使用当前业务 API key；设置分别保存两者的加密凭据，也兼容环境变量方式。展示当前 key 上限、消耗进度条和 credit 总余额（total_credits − total_usage），null 上限明确显示未设限额，0 保持为 0。两个请求独立，某一项失败不遮掉另一项结果。[官方 credit 接口](https://openrouter.ai/docs/api/api-reference/credits/get-remaining-credits)、[当前 key 接口](https://openrouter.ai/docs/api/api-reference/api-keys/get-current-api-key)。

Claude API 来源沿用官方组织用量查询；普通 API 账户余额未有本实现支持的公开查询接口，气泡明确显示“剩余额度：接口未提供”，不将 token 用量当剩余额度。Enterprise 成员 Spend Limits 属于不同产品，不用于替代 API 账户余额。

## 音乐

- 网易云、QQ 音乐、Spotify 分别勾选；自动跟随总开关开启时，已勾选播放器播放才启动律动。手动律动暂停自动跟随，保留来源选择。
- 点击进入所有额度来源之后的台词页时，播放中的已勾选歌曲显示歌词并常驻，暂停后恢复台词。具体点击次数随启用来源数量变化；无进度、无歌词、匹配失败会明确提示。
- 网易云沿用本地桌面 MCP；QQ 音乐和 Spotify 通过 Windows 媒体会话读取曲名、歌手、播放进度。客户端必须向 Windows 发布媒体信息；浏览器播放器、未发布媒体会话的客户端不保证识别。
- 新工具 `desktop_music_get_now_playing` 接收 `providers` 数组。多个已勾选播放器同时播放时优先采用媒体时间线最近更新者；时间相同时按网易云、QQ 音乐、Spotify 排序。
- QQ / Spotify 歌词匹配网易云曲库，仅接受唯一的同名同歌手结果，有时长时须在 3 秒误差内；不保证曲库覆盖。结果携带 `netease_match` 来源。不读取音乐账号凭据。
- Windows 媒体助手首次运行使用系统 .NET Framework 编译；生成文件在 `runtime-bin/`，不入库。

## 模型与用量

Credit 来源（包括 OpenRouter、DeepSeek、硅基流动）在气泡与设置卡片中共用布局：当前 Key limit → 当前 key 消耗进度条 → 账户总余额。OpenRouter 有限额时按 limit − limit_remaining 计算当前窗口消耗，不使用累计 usage 代替当前窗口；未设限额时显示已用金额但不生成百分比。缺少 key 限额或消耗的接口显示“未提供”和灰色空条；账户余额单独保留，不混入 key 的进度。零限额不做除法，超限进度最多填满。

设置默认打开用量页，按来源顺序展示已启用厂商及本机 token 卡片。添加／编辑厂商配置查询开关，可直接粘贴密钥并保存；环境变量是可选兼容方式。查询类型与地址由厂商确定。可添加 Ark、OpenRouter、OpenAI、Claude API、DeepSeek、硅基流动；Ark 直接复用现有连接。不支持查询的 Gemini 和自定义接口不在添加列表中。推理地址、接口类型、模型列表已移出设置界面。

本地统计与账户查询分开展示，不相加：

| 来源 | 口径 |
| --- | --- |
| 本机 Codex | 当前与归档日志的会话累计 token，按会话 ID 去除归档副本及重复累计快照；缓存输入是输入的子集。分叉继承、删除记录可能影响累计，不代表账户账单 |
| 本机 OpenCode | 只读 SQLite 的 session_v2 累计字段或旧 message token 字段，缓存、推理单列；不存在或未知版本明确提示 |
| OpenAI | 官方组织 completions 用量接口，最近 7 天，需要 Admin API key；缓存输入包含在输入中 |
| Anthropic | 官方组织 messages 用量接口，最近 7 天，需要管理密钥；未缓存输入、缓存读写、输出分别列出 |
| DeepSeek / 硅基流动 | 官方账户余额，不换算 token |
| Ark Coding Plan | 既有官方套餐查询的 5 小时与每周剩余比例，不换算 token |
| Gemini / 自定义 | 尚无此实现支持的账户汇总接口，明确显示不支持；不从兼容推理接口猜测用量 |

默认直接在密码框粘贴 API key，点击「保存并查询」立即生效，无须配置环境变量或重启。密钥通过 Windows DPAPI CurrentUser 加密写入本机 providers.json，仅当前 Windows 用户可解密；编辑时不回显，留空保留已有密钥，也可明确清除。保存后回读校验；查询通过单次标准输入管道传递来源快照和凭据，不写入明文文件、不放入命令行、不修改系统或用户环境变量。结果绑定本次请求编号。解密失败明确报错，不静默切换其他凭据。

Windows PowerShell 5.1 的 JSON 数组读取使用直接赋值，避免额外数组包装使来源列表变成嵌套数组，从而丢失启用状态和已保存密钥。

OpenRouter 的当前 key 和 Credit 管理密钥分别填写；管理密钥可暂不填，此时仅查询当前 key 限额。OpenAI / Anthropic 仍需要具有管理查询权限的密钥。旧环境变量配置继续兼容，并收进「环境变量（可选）」折叠项。查询请求固定到对应官方域名且拒绝重定向，自定义推理地址不会收到管理密钥。

默认 Codex 目录尊重 `CODEX_HOME`，OpenCode 数据库可通过 `OPENCODE_DB` 指定。厂商查询读取最近 7 天；本机统计读取本机现存记录，各自时间范围均显示。

配置与结果在安装配置指定的 dataDir：`providers.json`、`provider-usage.json`、`music-sources.json`，均不入库。查询异步执行，失败不显示为 0。Ark 延用独立异步刷新与过期判断。

官方接口依据：[OpenAI](https://developers.openai.com/api/reference/resources/admin/subresources/organization/subresources/usage/methods/completions)、[Anthropic](https://platform.claude.com/docs/en/manage-claude/usage-cost-api)、[DeepSeek](https://api-docs.deepseek.com/zh-cn/api/get-user-balance/)、[硅基流动](https://siliconflow.readme.io/reference/user-info)。

## 外观与交互

「台词」标签集成自动台词开关、1／5／15 分钟显示间隔、带权重的台词编辑、保存与恢复内置台词。右键的旧编辑入口直接切换到该标签，不再创建独立编辑窗口；未保存草稿在隐藏设置浮窗后仍保留。

设置浮窗使用浅紫卡片、圆角按钮与开关。人物／气泡大小、声音、自动语录、显示与位置和更新改为内联设置行，低频子项可展开；更换形象与编辑语录保留直接入口。界面仅显示功能标签、指标、必要状态与错误，不显示验收和实现说明。原始设置函数继续共用，100 BPM 和已有各方向吸附律动保持。

## 验证

- Node: `node --test gpt-niang-usage/tests/provider-usage.test.mjs`；音乐模块 `npm test`。本机代理环境须让 `127.0.0.1,localhost` 直连。
- WPF: `pwsh.exe -NoProfile -STA -File gpt-niang-usage/tests/settings-window.test.ps1`；点击顺序与原设置菜单测试。
- 当前机器验证网易云 MCP 与 Windows 媒体读取；QQ / Spotify 的选择、缺失状态及切歌保护使用模拟数据验证，真实客户端播放仍需现场验证。厂商无配置密钥时返回未配置，账户 API 使用模拟响应验证，不消耗推理额度。
