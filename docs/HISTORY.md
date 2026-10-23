# 开发历史

下文保留早期本地原型的开发记录；其中的分支、备份及“尚未公开”描述属于当时状态，并非当前发布说明。当前功能与运行步骤请以根目录 README.md 为准。

## 2026-10-24 公开仓库整理

- 保留 GPT-Niang 与素材来源、版权和非商业使用说明，补充 Windows 桌宠主页和动作预览。
- 限制任务状态记录的数量与保留时间，避免长时间运行时持续积累会话标识。
- 补全动画帧缓存退出时的线程同步资源清理。
- 修复便携打包漏掉版本元数据的问题；按白名单打包并验证 ZIP CRC 和每个文件的 SHA-256。
- Windows 测试汇总遇到子测试失败时返回失败，新增缓存和测试汇总的回归验证。
- 支持指定独立数据目录进行启动检查，并增加 Windows 自动检查流程。

## 2026-10-22 体验升级

- 保留成熟 WPF、跟随、额度和异常恢复模块，在独立 dragon-experience-upgrade-20261022 分支增量修改；原修改未清理，上版运行代码和完整帧包在项目 work/upgrade-backup-20261022-172355 本地备份。
- 新增 runtime/dragon-frame-cache.cs、dragon-behavior.ps1、dragon-state-monitor.mjs；修改 dragon-video.ps1、dragon-animation.ps1，加入 40 帧后台缓存、正向循环、140ms 切换、自主行为、菜单分组与开关保存。
- completion-monitor.mjs 仅增加可注入事件解析器，保留上游默认行为；新解析器只处理白名单事件，不导出聊天、会话 ID 或凭据。本轮结束回待机，绝不自动当成任务成功庆祝。
- widget.ps1 为透明画布增加显示补偿；color-theme.ps1 在保留用户自定义语录的前提下接入本地性格台词。新增 assets/dragon-personality.json。
- 帧包重新排版为 512×512、831 帧，待机和思考选正向循环段，超级傲娇恢复普通角色大小；原视频未改，等待/失败素材保留。
- Dragon-Control.ps1 增加 ambient/speech/link/speak；修复 Windows PowerShell 5.1 使用空备份路径替换命令文件时的兼容性问题。
- 新增 tests/Verify-Dragon-Behavior.ps1、gpt-niang-usage/tests/dragon-state.test.mjs、tools/upgrade-animation-pack.py、tools/preview-upgraded-pack.py；prepare-video-pack.py 追加模式适配扩展画布；package-portable.py 纳入本轮说明。
- 新增 README-Experience.md、当前接触表、透明 WebP、Dragon-Experience-Upgrade.mp4 与 video-upgrade-*.json；更新说明和测试记录，重建便携 ZIP 和 SHA256 清单。没有发布到远程仓库或修改启动项。

## 2026-10-21 视频预览版补充

- 新增 `runtime/dragon-video.ps1`：配置化本地透明帧包、24 帧缓存、单次/循环/往返播放；原 v5 图集仍可回退。
- 扩展 `runtime/dragon-animation.ps1`：共用时钟、动态尺寸 alpha 命中、自动动作菜单和 `clip` 命令；业务状态仍为手动事件。
- `widget.ps1` 左键点击增加傲娇回应；额度气泡行为保留。`Dragon-Control.ps1` 增加 clip 入口。
- 新增 `assets/dragon-video/pack.json`、四组共 544 个透明 PNG 帧及静态预览。
- 新增 `tools/prepare-video-pack.py`、`tests/Verify-Video-Pack.ps1`；运行验证脚本等待命令完成回执，避免把读取请求与处理完成混淆。
- 新增 `README-Video.md`、透明 WebP 动画、`video-pack-preview.jpg`、`Dragon-Showcase.mp4` 及帧/运行验证记录。
- 打包器改为生成独立 `GPT-Dragon-Pet-Video-Preview.zip`，保留之前的图集原型 ZIP。源码原始视频未更改。

---

基于上游 b6f5eb8972d1802821006b7208d20a834fa6a08b，本地独立 `dragon-prototype` 分支；没有修改研究用的 work/GPT-Niang checkout，没有公开推送。

修改既有文件：

- `.gitignore`：排除 Python 缓存，沿用 installation/config/runtime/日志排除规则。
- `gpt-niang-usage/widget.ps1`：龙娘动画初始化、形象切换时启停、独立桌面默认值、首次未连接视觉树的定位保护、桌面就绪逻辑、托盘/隐藏/命令 hook、退出清理 hook、关闭上游二进制更新、准确的「接口快照」标签。
- `gpt-niang-usage/widget.xaml`：窗口标题改为 GPT Dragon Pet。
- `gpt-niang-usage/assets/characters.json`：增加 dragon-v5 动态角色入口。

新增代码和文档：

- `DragonHost.cs`、`GPTDragonPet.exe`、`Build-Dragon.ps1`。
- `Start-Dragon.ps1`、`Start-Dragon.vbs`、`Dragon-Control.ps1`。
- `gpt-niang-usage/runtime/dragon-animation.ps1`。
- `tools/prepare-atlas.py`、`tools/package-portable.py`。
- `tests/Verify-Running-Dragon.ps1`、`tests/Run-Upstream-Checks.ps1`、`tests/verify-atlas.py`。
- `README-Dragon.md`、`THIRD-PARTY.md`、`TEST-RESULTS.md`、本清单。

新增素材目录 `gpt-niang-usage/assets/dragon-v5/`：

- 原始 `pet.json`、`spritesheet.webp`、`README.md`、`validation.json`、`visual-review.json`。
- `UPSTREAM-LICENSE`、`UPSTREAM-LICENSE-MIT`、`UPSTREAM-NOTICE.md`。
- 衍生 `spritesheet.png`、`idle.png` 和明确的 `atlas-layout.json`。

构建/验证产物：六个 `preview-*.png`、`dragon-states.png`、`verification.json`、`PORTABLE-MANIFEST.json`；父目录便携 ZIP 和 SHA256SUMS.txt。不把本机 installation.json、账号快照、身份哈希、日志或真实桌面截图纳入 ZIP。

额度实现、worker/刷新队列、原生跟随模块、原菜单和原有测试源码均未改写。完整上游 checkout 为研究/后续开发保留；便携 ZIP 仅包含明确白名单中的 Windows 运行资源与新增源码。
