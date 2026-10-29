# GPT 娘位置姿势

运行时资源：

- `drag-pickup-sheet.png`：2×2 四帧透明动画。背后衣服被拎起、保持无口，双臂和双腿交替晃动；拖动时播放，松手或失去拖动状态时恢复对应姿势。

- `side-left.png`、`side-right.png`：竖边双手扒框，分别绘制，保留发饰侧别。由当前 GPT 娘身份图与侧边探头姿势参考生成。
- `bottom-left.png`：用户选择的南小鸟抢镜脸底稿迁移、清晰化及透明化结果。
- `bottom-right.png`：以上清晰版的右下角对应图，保留张嘴笑、紫色瞳孔和发饰方向。
- `top-left.png`、`top-right.png`：左右上角单独重绘的抢镜脸，发饰随角色朝向调整，头发自然下垂，不使用镜像成图。
- `top.png`：上沿中间的倒挂姿势，躯干在画面上沿之外，头发向下垂。生成提示词见 `top-poses.prompt.json`。

`top.png` 按用户最新选择恢复为最初生成的倒挂原图，保留完整的顶部服饰，不使用后续双手扒框与去除横线的版本。后续版本生成记录保留在 `top-grip.prompt.json`，仅作历史记录。运行时仍以水平斜切实现摆动，上沿固定。

这些图由内置 imagegen 制作。原 GPT 娘身份图的说明见 `../CHARACTER-NOTICE.txt`；角色及参考作品的权利归原权利人，不因代码 MIT 许可获得额外图片授权。

最新角落版进一步统一了浅肤色、淡紫色分层眼睛与简化瞳孔，保留原来的张嘴抢镜表情。此轮提示词记录在 `tone-correction.prompt.json`，运行时显示占比由 `Get-WidgetPoseScale` 单独校准。

姿势参考页面：
- <https://www.clipartmax.com/middle/m2i8b1d3G6H7H7d3_crystal-maiden-by-chroneco-crystal-maiden-dota-2-chibi/>
- <https://mzh.moegirl.org.cn/抢镜脸>

完整制作过程保留在本项目 `assets/concepts/` 与 `gpt-dragon-kotori-peek.prompt.json`。本目录不包含下载的第三方参考原图。
