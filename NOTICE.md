# NOTICE

本仓库为**合集**性质，内容分三类，各自归属如下。

## 1. 覆盖层语言包与 `.ovl` 二进制 —— 第三方

`overlays/` 下的全部 `zh-Hans.json` / `zh-Hant.json`，以及安装脚本会下载的 `.ovl` 文件，
**全部来自以下作者的公开发布**，本仓库仅做整理与转存（JSON 文本）：

| 项目 | 作者 | 仓库 |
|---|---|---|
| 中文版覆盖层的构建与翻译 | zdm65477730 | https://github.com/zdm65477730 |
| 覆盖层本体上游 | ppkantorski | https://github.com/ppkantorski |

具体到每个文件的来源仓库、发布 tag、资产名与 SHA-256，见 [`overlays/SOURCES.md`](overlays/SOURCES.md)。

- 这些内容版权归各自作者所有，遵循其原仓库的许可条款；本仓库的 MIT 许可**不适用于**这些文件。
- 本仓库**不重新分发** `.ovl` 等二进制，安装脚本在运行时从原作者的官方发布地址下载并校验 SHA-256。
- 若原作者撤下发布或修改内容，请以官方发布页为准，本仓库会同步更新 `SOURCES.md`。

## 2. `hekate-zh/` —— 本仓库自制

- `hekate_ipl_cn.ini`：本仓库编写的 Hekate 启动项配置模板（中文段名）。
- `icons/*.bmp`：本仓库生成的启动项图标（AI 辅助生成 + 程序化修整）。

## 3. `docs/`、`install/` —— 本仓库自制

安装脚本与机制说明文档由本仓库编写，其中引用的源码行号分别来自
[Atmosphere-NX/Hekate](https://github.com/Atmosphere-NX/Hekate)、
[Atmosphere-NX/Atmosphere](https://github.com/Atmosphere-NX/Atmosphere) 与
[ppkantorski/ovl-sysmodules](https://github.com/ppkantorski/ovl-sysmodules)（MIT 许可）。

## 免责声明

本仓库与 Nintendo 无关联。所有内容仅供学习交流，使用风险自负。
请遵守各上游项目的许可协议，不要将本仓库用于商业分发。
