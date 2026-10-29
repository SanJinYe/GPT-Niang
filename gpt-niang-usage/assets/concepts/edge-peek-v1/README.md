# 侧边扒框探头 · 第一版概念图

本轮是姿势研究与形象迁移，未改动吸附代码、未替换默认立绘，也这些候选图片仅作历史记录。

## 姿势定义

身体藏在应用窗口后，两只手一上一下抓住同一条竖向边框。手指弯曲搭在边缘上，头和少量肩膀从窗口外侧探出，歪头约 15–20°，看向用户。左侧版向左探，右侧版向右探。

保留原版白发紫瞳、半睁眼、白色龙角、尖耳、结形发饰、白紫高领衣服、粗紫色描边和无嘴表情。左右版分别绘制，右侧版保留发饰的角色侧别，不对整张图机械镜像。

- `gpt-niang-edge-left.png`：左窗框，图中抓握边在右侧。
- `gpt-niang-edge-right.png`：右窗框，图中抓握边在左侧。
- 两张均为真正带 alpha 通道的透明 PNG；用于评估姿势与画风，接入前仍应按显示尺寸检查抓握位置与裁切。

## 网图参考

- Crystal Maiden by Chroneco，侧边探头姿势参考：<https://www.clipartmax.com/middle/m2i8b1d3G6H7H7d3_crystal-maiden-by-chroneco-crystal-maiden-dota-2-chibi/>
- 白发 Q 版探头图，用于比较头部比例与手部姿势（双手在横边，不作为最终竖边抓握构图）：<https://imgbin.com/png/2LMYKNHE/curious-chibi-girl-curious-chibi-girl-peeking-png>
- Sayori 竖边探头，可作轮廓参考：<https://www.pngaaa.com/detail/2143015>

以上是第三方转载站的参考页面，不视为原作者授权声明。参考图保存在忽略目录 `.local/references/edge-peek`，不作为产品素材提交。

## 生成记录

使用内置 imagegen；未使用付费 API/CLI 回退。身份参考为本项目的 `assets/gpt-dragon-niang-bust.png`；左版另参考 Crystal Maiden 的侧边姿势，右版参考左版已生成结果。完整提示词见 `prompts.json`。

原角色与原图权利说明继续参见 `../../CHARACTER-NOTICE.txt`，此概念目录不扩张原素材的授权范围。

## 后续吸附接入要点

以双手的抓握线为锚点对齐实际窗框，而不是对齐图片外接矩形。左、右吸附分别选择对应资源；纵向拖动只移动抓握位置。头部探出可用短距离位移与轻微回弹表现，避免继续旋转整张图导致手离开边框。窗口贴住屏幕边缘时，外侧可能没有显示空间，届时需决定改为向内探或留在可视区域。
