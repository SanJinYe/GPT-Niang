# GPT-Niang · GPT 娘定制版

一只陪在 Codex 窗口边上的白发紫瞳小龙娘：查看额度、跟着音乐律动，也可以拎起来放到窗口的不同位置。

本仓库是 [T7moris/GPT-Niang](https://github.com/T7moris/GPT-Niang) 的定制 fork，基于上游 1.3.5，新增多来源用量查询、音乐联动、位置形象、实时吸附和统一设置浮窗。**本页新增功能目前只在 Windows 上实现与验证。** macOS 原有代码保留，使用范围见 [macOS README](macos/README.md)。

[获取本分支源码](https://github.com/SanJinYe/GPT-Niang/tree/feature/local-companion-customizations) · [安装与启动](#安装与启动) · [使用方法](#使用方法) · [配置额度来源](#配置额度来源) · [音乐接入](#音乐接入) · [反馈问题](https://github.com/SanJinYe/GPT-Niang/issues)

<table>
  <tr>
    <td align="center"><img src="https://raw.githubusercontent.com/SanJinYe/GPT-Niang/feature/local-companion-customizations/gpt-niang-usage/assets/gpt-dragon-niang-bust.png" alt="GPT 娘默认／下方形象" height="180"><br>默认／下方</td>
    <td align="center"><img src="https://raw.githubusercontent.com/SanJinYe/GPT-Niang/feature/local-companion-customizations/gpt-niang-usage/assets/dock-poses/top.png" alt="GPT 娘上方倒挂形象" height="180"><br>上方倒挂</td>
    <td align="center"><img src="https://raw.githubusercontent.com/SanJinYe/GPT-Niang/feature/local-companion-customizations/gpt-niang-usage/assets/dock-poses/drag-pickup-sheet.png" alt="GPT 娘提起四帧形象" height="180"><br>提起四帧</td>
  </tr>
  <tr>
    <td align="center"><img src="https://raw.githubusercontent.com/SanJinYe/GPT-Niang/feature/local-companion-customizations/gpt-niang-usage/assets/dock-poses/side-left.png" alt="GPT 娘左侧扒框形象" height="180"><br>左侧扒框</td>
    <td align="center"><img src="https://raw.githubusercontent.com/SanJinYe/GPT-Niang/feature/local-companion-customizations/gpt-niang-usage/assets/dock-poses/side-right.png" alt="GPT 娘右侧扒框形象" height="180"><br>右侧扒框</td>
  </tr>
  <tr>
    <td align="center"><img src="https://raw.githubusercontent.com/SanJinYe/GPT-Niang/feature/local-companion-customizations/gpt-niang-usage/assets/dock-poses/top-left.png" alt="GPT 娘左上抢镜形象" height="180"><br>左上抢镜</td>
    <td align="center"><img src="https://raw.githubusercontent.com/SanJinYe/GPT-Niang/feature/local-companion-customizations/gpt-niang-usage/assets/dock-poses/top-right.png" alt="GPT 娘右上抢镜形象" height="180"><br>右上抢镜</td>
    <td align="center"><img src="https://raw.githubusercontent.com/SanJinYe/GPT-Niang/feature/local-companion-customizations/gpt-niang-usage/assets/dock-poses/bottom-left.png" alt="GPT 娘左下抢镜形象" height="180"><br>左下抢镜</td>
    <td align="center"><img src="https://raw.githubusercontent.com/SanJinYe/GPT-Niang/feature/local-companion-customizations/gpt-niang-usage/assets/dock-poses/bottom-right.png" alt="GPT 娘右下抢镜形象" height="180"><br>右下抢镜</td>
  </tr>
</table>

## 新增功能

| 功能 | 当前行为 |
| --- | --- |
| 多来源额度轮播 | Codex 在前，已启用的来源按添加顺序显示，最后是台词或歌词，再次点击收起 |
| API credit 展示 | 统一显示当前 key limit、key 消耗进度条和账户总余额；不支持的字段明确标注 |
| 直接导入密钥 | 在设置中粘贴密钥，点击「保存并查询」即生效；本机加密保存，无需设置环境变量或重启 |
| 本机 token 统计 | 分别读取 Codex 会话记录和 OpenCode 本地数据库，与厂商账户数据分开展示 |
| 多播放器联动 | 网易云音乐、QQ 音乐、Spotify 可分别勾选，播放时自动进入律动 |
| 同步歌词 | 播放中的已勾选歌曲在台词页显示歌词，并保持气泡可见 |
| 八方向吸附 | 上、下、左、右及四个角落使用对应形象，配有探头过冲与回弹 |
| 提起动画 | 从背后拎住衣服，保持无口，四肢四帧循环晃动 |
| 手势区分 | 短按用于查看额度和台词，移动或长按才提起，松手不会额外翻页 |
| 统一设置浮窗 | 圆角悬浮卡片，集中管理音乐、用量、外观与交互、台词；启动前后右键菜单一致 |

保留上游的窗口跟随、桌面模式、角色图库、人物与气泡独立缩放、点击音效、自定义 WAV、回答结束提醒等能力。

## 使用方法

### 点击：额度 → 来源 → 台词／歌词

短按角色或点击气泡，依次显示：

```text
Codex → 来源 1 → 来源 2 → … → 台词／歌词 → 收起
```

例如启用顺序为 Ark、OpenRouter、Claude API：

| 点击次数 | 显示内容 |
| --- | --- |
| 1 | Codex 订阅额度 |
| 2 | Ark Coding Plan 额度 |
| 3 | OpenRouter 当前 key 限额、消耗进度条和总余额 |
| 4 | Claude API 当前实现支持的用量信息 |
| 5 | 台词；已勾选播放器正在播放时显示歌词 |
| 6 | 收起气泡 |

未添加其他来源时，Codex 后直接进入台词页。禁用来源会跳过，重新启用会追加到末尾。当前定制版隐藏 Codex 的 5 小时栏；Ark 仍显示 5 小时与每周剩余比例。

普通气泡约 5 秒后收起；后台查询中会暂缓收起，播放中的歌词保持显示。刷新按钮单独执行刷新，不推进轮播。失败、过期和未配置不会显示成零余额。

### 拖动：提起、实时吸附与回弹

- **短按松手**：保留 Q 弹按压与回弹，切换额度或台词，不提起。
- **按住约 0.2 秒，或移动达到 6 DIP**：进入提起状态。6 DIP 相当于 100% 缩放下约 6 像素，随系统缩放调整。
- **拖近边框或角落**：在松手前就可以切换为吸附姿势，先探出一些，再回弹到位。
- **离开吸附区域**：恢复提起动画；同一次拖动可以多次进出不同边缘。
- **松手**：保留当前吸附；不满足吸附条件时恢复默认下方半身形象。

提起后的免吸附期为 **min（0.5 秒，松开鼠标）**。豁免结束且满足条件时，吸附动画直接替换当前动画，不先闪回默认形象。边缘判定带防抖，停在原处不会反复播放。

侧边使用扒框形象，角落使用抢镜探头形象，上沿使用头发自然下垂的倒挂形象。各姿势按面部大小校准；当前提起图为校准尺寸的 0.9 倍。这些专属姿势用于内置 GPT 娘，自定义导入图片保持其原有形象。

### 右键：统一设置

右键角色，选择「设置」。默认打开用量页，窗口可拖动，右上角关闭或按 Esc 收起。

| 标签 | 可调整内容 |
| --- | --- |
| 音乐 | 播放器选择与连接状态、自动跟随、手动律动、迪灯、左右移动 |
| 用量 | 添加／编辑来源、导入密钥、刷新账户数据、本机 token、Ark 套餐额度 |
| 外观与交互 | 角色图库、人物与气泡大小、声音、窗口跟随／桌面模式、置顶、更新 |
| 台词 | 台词编辑与权重、保存、恢复内置台词、自动台词开关及 1／5／15 分钟间隔 |

台词每行一句、每句最多 200 字；可写 `3 | 这句台词` 提高出现权重。恢复内置台词前会备份自定义文件。

## 配置额度来源

打开 **设置 → 用量 → 添加厂商**，选择来源并启用查询。除 Ark 外，可直接粘贴对应密钥，再点「保存并查询」。编辑已保存的密钥时，输入框不会回显明文；留空保持不变，也可以明确清除。

| 来源 | 当前可查询内容 | 接入要求 |
| --- | --- | --- |
| Codex | 当前登录账户的订阅额度 | 已安装 Codex，并使用 ChatGPT 账户登录；固定为第一项 |
| Ark Coding Plan | 5 小时、每周剩余比例 | 额外配置本地 Ark 查询工具与登录，见下文 |
| OpenRouter | 当前 key limit、当前窗口消耗、账户 credit 总余额 | 普通 API key；总余额另需管理密钥 |
| OpenAI | 近 7 天组织 completions 的 token 用量 | 有组织用量查询权限的 Admin API key |
| Claude API | 近 7 天组织 messages 的 token 用量 | 有组织用量查询权限的管理密钥；当前实现不查询 API 账户剩余余额 |
| DeepSeek | 账户余额 | API key；当前未接入 key 限额和消耗查询 |
| 硅基流动 | 账户余额 | API key；当前未接入 key 限额和消耗查询 |

Credit 来源共用 **key limit → key 消耗进度条 → 总余额** 的布局。key 未设限额时不计算百分比；接口未提供 key 数据时显示「未提供」，保留可查询的账户余额。Gemini 和自定义兼容接口目前不在可添加的查询列表中。

### OpenRouter

1. 添加 OpenRouter，将正在使用的普通 API key 粘贴到「API 密钥」。
2. 若要查账户总余额，到 [Management Keys](https://openrouter.ai/settings/management-keys) 创建管理密钥，粘贴到「管理密钥（可选，用于 Credit）」。
3. 点击「保存并查询」。只有普通 key 时，仍可查看当前 key 限额。

两个密钥分别用于当前 key 与账户 credit 查询。某一项失败不会隐藏另一项结果。

### Ark 与本机 token

Ark 依赖外部 `opencode-ark-handoff/handoff.py` 的 `usage` 命令和官方控制面登录，该工具不随本仓库分发。按 [定制集成说明](docs/custom-integrations.md#ark-额度) 配置 `ark-connection.json` 后，挂件复用该连接查询套餐。

本机 token 无需厂商密钥：从现存 Codex 会话日志（含归档）和 OpenCode 数据库提取计数。统计范围、缓存字段和来源分别展示，**不与账户用量相加，也不等同账单**；分叉继承、删除记录等会影响累计值。可通过 `CODEX_HOME` 和 `OPENCODE_DB` 指定记录位置。

这里配置的是查询来源，模型调用仍由你原来的客户端管理。详细口径见 [音乐与用量设置](docs/music-and-usage-settings.md)。

## 音乐接入

### 配置桥接程序

音乐入口需要本地桥接程序。首次使用请按 [定制集成说明](docs/custom-integrations.md#网易云与歌词) 完成以下配置：

1. 在 `integrations/netease-desktop-mcp/` 执行 `npm ci --ignore-scripts`，使用 Node.js 24 或更高版本。
2. 在挂件数据目录创建 `music-connection.json`，填写 Node 和 `widget-bridge.mjs` 的实际路径。
3. 使用网易云时，运行该目录的 `Connect-CloudMusic.cmd`，开启本机控制通道；需要 PowerShell 7。普通启动的客户端可能需要重启，播放会短暂中断。
4. 打开「设置 → 音乐」，勾选播放器并开启「自动跟随」。

QQ 音乐与 Spotify 通过 Windows 媒体会话读取播放信息，仍需配置上述桥接程序；客户端必须向系统提供媒体信息。聊天中控制网易云的 MCP（模型上下文协议）连接是可选功能，另见 [音乐桥接 README](integrations/netease-desktop-mcp/README.md)。

### 律动与歌词

- 自动跟随已勾选播放器的播放／暂停状态；手动律动会暂停自动跟随，保留来源选择。
- 律动频率固定为 **100 BPM**，迪灯和左右移动可独立开关。
- 下方律动带音响和墨镜；侧边带白色头戴耳机和墨镜；角落带墨镜与飘动音符；上沿使用墨镜与轻微斜切摆动。
- 进入轮播末尾的台词页时，有正在播放的已勾选歌曲就显示当前歌词；暂停后恢复台词，也可继续点击收起。
- 网易云按歌曲 ID 读取歌词。QQ／Spotify 使用曲名、歌手及可用时长匹配网易云曲库；匹配不唯一、缺少进度或无歌词时明确提示。
- 多个来源同时播放时，优先选择最近更新时间的已勾选媒体会话；时间相同按网易云、QQ 音乐、Spotify 排序。

网易云连接已做本机验证。QQ／Spotify 的选择与切歌保护经过模拟测试，真实客户端覆盖仍有限；浏览器播放器和未发布媒体会话的客户端不保证识别。

## 安装与启动

### 环境与支持范围

- **Windows 10 / 11**、Codex 桌面端及 ChatGPT 账户登录。
- 使用完整新增功能请准备 **Node.js 24+**。基础安装器的最低检查仍为 Node.js 20，但音乐桥接要求 24+，旧版本可能无法提供本机数据库统计。
- Windows 挂件沿用 PowerShell 5.1 / WPF 运行；音乐连接脚本和下面的开发检查使用 PowerShell 7（`pwsh.exe`）。

当前功能位于 **`feature/local-companion-customizations`** 分支。这个 fork 目前没有包含这些定制的一键正式发布包；上游安装包不包含本页新增能力。

### 从源码安装

可在[本分支页面](https://github.com/SanJinYe/GPT-Niang/tree/feature/local-companion-customizations)选择 **Code → Download ZIP** 并完整解压，也可使用 Git：

```powershell
git clone --branch feature/local-companion-customizations https://github.com/SanJinYe/GPT-Niang.git
cd GPT-Niang
.\安装GPT娘.cmd
```

保留 `.agents`、`gpt-niang-usage` 等完整目录。安装器会以当前目录注册运行位置、插件与启动入口，因此请先放到长期保留的位置，安装后不要直接删除或移动。安装主挂件后，音乐桥接和 Ark 仍需按前述说明单独配置。

| 操作 | 入口 |
| --- | --- |
| 安装或重新注册 | 根目录 `安装GPT娘.cmd` |
| 退出后重新打开 | 根目录 `打开GPT娘.cmd`；重复启动不会叠加第二只 |
| 临时退出 | 右键 →「退出 GPT 娘」 |
| 停用自动显示和插件登记 | 根目录 `停用GPT娘.cmd`；保留程序与偏好文件 |

### 更新

Windows 安装副本的更新检查只访问 **SanJinYe/GPT-Niang**，不会回退到原作者仓库覆盖定制功能。没有正式发布包时显示「定制仓库暂无正式版」。设置页可发起检查，实际安装等待编辑窗口关闭。

Git 源码目录使用 Git 更新，内置更新器不会覆盖 checkout：

```powershell
git pull --ff-only origin feature/local-companion-customizations
```

有自己的修改时先处理合并；如运行副本与源码目录分开，需将已验证改动部署到运行副本。基础功能的上游历史见 [更新记录](更新记录.md)。

## 数据与隐私

- Codex 订阅额度通过现有登录状态只读查询，不创建聊天或调用模型。厂商查询只访问对应官方查询接口，不发送推理请求。
- 直接粘贴的密钥使用 Windows 当前用户加密保护（DPAPI）保存在本机，编辑时不回显；后台查询通过一次性进程管道传递，不写入命令行或明文配置。旧环境变量方式仍在可选项中。
- 本机 token 统计只提取计数字段，不把聊天正文上传给厂商。音乐匹配会把曲名、歌手发送给网易云歌词接口；磁盘音乐状态只保存当前歌词行，不保存完整歌词文件。
- 配置、密钥密文、账户快照、歌词状态和运行日志不提交到 Git。默认数据目录是 `%LOCALAPPDATA%\GPTNiangUsage\state`，实际位置以安装配置为准。

## 常见问题

**保存密钥后输入框为什么是空的？** 这是不回显的设计。查看卡片上的「API 密钥已保存」状态；重新编辑时留空会保留已保存密钥。

**为什么 OpenRouter 的 key 限额能查，但总余额不能？** 总余额需要单独配置管理密钥，普通 API key 用于查询自身限额。

**为什么部分来源没有进度条数值？** 当前接口未提供 key 限额／消耗，或 key 没有上限。界面不会用账户余额猜测 key 的额度。

**为什么短按不再立刻提起？** 短按用于额度和台词轮播；移动或长按确认拖动后才提起，避免两种操作冲突。

**为什么音乐没有联动？** 先检查桥接配置，再看播放器卡片的连接状态、来源勾选与自动跟随开关。网易云还需要本机控制通道；QQ／Spotify 需要提供 Windows 媒体信息。

**macOS 能使用这些新增功能吗？** 当前未移植这轮 Windows 定制。macOS 原生应用的基础安装、构建和能力见 [macOS README](macos/README.md)。

## 开发与验证

```powershell
# 挂件 Node 测试
npm --prefix gpt-niang-usage test

# 音乐桥接测试；先在集成目录完成 npm ci --ignore-scripts
npm --prefix integrations/netease-desktop-mcp test

# 列出 Windows 注册用例
pwsh.exe -NoProfile -File gpt-niang-usage/tests/run-windows-tests.ps1 -List

# 运行关键 Windows 回归
pwsh.exe -NoProfile -STA -File gpt-niang-usage/tests/run-windows-tests.ps1 -TestNames review-fixes,live-docking,settings-window,settings-menu,provider-background,provider-cycle,credit-layout
```

测试入口按文件隔离执行并显式加载 UTF-8，可用 `-TestNames` 选择用例。不指定筛选时执行全部注册文件；不同宿主及真实音频／窗口环境的要求以各测试为准。本机代理需允许 `127.0.0.1`、`localhost` 直连。

当前记录：Node 测试 148 项通过、1 项跳过；音乐桥接 62 项通过；16 个关键 Windows 测试文件通过。Windows 入口注册 75 个文件，这不表示本轮全部执行。详细验证范围见 [审查修复记录](docs/review-fixes.md)。

| 目录／文件 | 用途 |
| --- | --- |
| `gpt-niang-usage/widget.ps1`、`widget.xaml` | Windows 挂件入口与布局 |
| `gpt-niang-usage/runtime/` | 手势、姿势、设置、额度、音乐与更新模块 |
| `gpt-niang-usage/assets/dock-poses/` | 吸附形象与提起动画帧 |
| `gpt-niang-usage/tests/` | 逻辑、交互和 Windows 渲染检查 |
| `integrations/netease-desktop-mcp/` | 网易云桌面 MCP 与多播放器桥接 |
| `macos/` | 上游保留的 macOS 原生应用 |
| `docs/` | 集成、姿势、交互和审查说明 |

## 致谢与许可

感谢 [T7moris](https://github.com/T7moris) 及上游贡献者提供原项目。原 README 的完整贡献名单保留在[上游致谢与贡献记录](docs/upstream-acknowledgements.md)。

网易云集成基于 [WalterT812/netease-desktop-mcp](https://github.com/WalterT812/netease-desktop-mcp)，保留其 [LICENSE](integrations/netease-desktop-mcp/LICENSE)、[第三方声明](integrations/netease-desktop-mcp/THIRD_PARTY_NOTICES.md) 和 [来源版本记录](integrations/netease-desktop-mcp/UPSTREAM.json)。

代码与一般文档采用 [MIT License](LICENSE)，保留 T7moris 及项目贡献者的版权声明。**角色图片、姿势图和参考相关素材不适用代码的 MIT 授权**，具体范围见 [角色与图片素材声明](gpt-niang-usage/assets/CHARACTER-NOTICE.txt) 与[姿势素材来源](gpt-niang-usage/assets/dock-poses/README.md)。第三方角色和作品权利归各自权利人所有。

内置语录中的上游文本保留 [MeteorNOX 的语录许可](gpt-niang-usage/assets/quotes-LICENSE.txt)。本项目不是 OpenAI 或各模型、音乐服务厂商的官方项目。
