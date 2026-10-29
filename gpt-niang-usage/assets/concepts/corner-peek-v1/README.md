# 下角斜探头 · 南小鸟抢镜脸构图参考

状态：姿势素材草稿，未替换运行中的默认形象，未接入新的角落吸附逻辑，作为历史概念稿保留。

## 形象与构图

借用南小鸟抢镜脸的构图：头部占大部分画面，从下角斜着探向窗口中心，身体主要藏在下边缘之外。白发紫瞳、龙角、尖耳、白紫服装、粗紫色描边和无嘴表情沿用 GPT 娘，不迁入参考人物的棕发、绿蝴蝶结或张嘴表情。

- `gpt-niang-bottom-left.png`：左下角版，贴左边和下边，向右上方探头。
- `gpt-niang-bottom-right.png`：右下角版，贴右边和下边，向左上方探头。
- 左右分别生成，发饰保持角色原本侧别，而不是简单镜像。
- 两张均为带真实 alpha 通道的透明 PNG。下边和相应侧边有意裁切；这是角落构图的一部分。

## 参考与生成

- 参考条目：<https://mzh.moegirl.org.cn/抢镜脸>
- 本轮查看的南小鸟图：<https://storage.moegirl.org.cn/moegirl/commons/2/24/LL_kotorileft_filter.png>
- 身份与画风参考：本项目 `assets/gpt-dragon-niang-bust.png`。
- 工具：内置 imagegen；使用透明背景模式，没有使用 CLI/API 回退。
- 完整提示词：`prompts.json`。

第三方参考图片仅保存在 `.local/references/corner-peek/`，没有复制进发布素材。GPT 娘身份来源与使用范围沿用 `../../CHARACTER-NOTICE.txt`。

## 接入定位

底角触发区需要同时接近水平下边与相应竖边；底角匹配优先于普通侧边匹配。以图片的 bottom-left 或 bottom-right 为角点对齐依据，按实际透明边界检查，不对这些图再应用左右镜像。离开底角后恢复普通侧边或自由状态；具体触发距离与过渡动画留待实现时按实际窗口尺度确定。
