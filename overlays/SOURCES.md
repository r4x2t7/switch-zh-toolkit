# 语言包来源清单

本目录下的 JSON 全部转存自下列公开发布，文件未做修改。
安装脚本会从同一批官方地址下载并校验 SHA-256。

| 覆盖层 (APPTITLE) | 文件 | 来源仓库 | 发布 tag | 资产名 | sha256 |
|---|---|---|---|---|---|
| EdiZon | zh-Hans.json | [zdm65477730/EdiZon-Overlay](https://github.com/zdm65477730/EdiZon-Overlay) | v1.0.8 | EdiZon.zip | 2a0db93c174fcfdb… |
| EdiZon | zh-Hant.json | [zdm65477730/EdiZon-Overlay](https://github.com/zdm65477730/EdiZon-Overlay) | v1.0.8 | EdiZon.zip | 2a0db93c174fcfdb… |
| FPSLocker | zh-Hans.json | [zdm65477730/ReverseNX-RT](https://github.com/zdm65477730/ReverseNX-RT) | v2.2.2 | ReverseNX-RT.zip | 0f78d4476b5ded7a… |
| FPSLocker | zh-Hant.json | [zdm65477730/ReverseNX-RT](https://github.com/zdm65477730/ReverseNX-RT) | v2.2.2 | ReverseNX-RT.zip | 0f78d4476b5ded7a… |
| QuickNTP | zh-Hans.json | [zdm65477730/QuickNTP](https://github.com/zdm65477730/QuickNTP) | 1.6.0 | QuickNTP.zip | 1ae65b3e2889f347… |
| QuickNTP | zh-Hant.json | [zdm65477730/QuickNTP](https://github.com/zdm65477730/QuickNTP) | 1.6.0 | QuickNTP.zip | 1ae65b3e2889f347… |
| ReverseNX-RT | zh-Hans.json | [zdm65477730/ReverseNX-RT](https://github.com/zdm65477730/ReverseNX-RT) | v2.2.2 | ReverseNX-RT.zip | 0f78d4476b5ded7a… |
| ReverseNX-RT | zh-Hant.json | [zdm65477730/ReverseNX-RT](https://github.com/zdm65477730/ReverseNX-RT) | v2.2.2 | ReverseNX-RT.zip | 0f78d4476b5ded7a… |
| ovl-sysmodules | zh-Hans.json | [zdm65477730/ovl-sysmodules](https://github.com/zdm65477730/ovl-sysmodules) | v1.3.2 | ovl-sysmodules.zip | 66f352f29c731c37… |
| ovl-sysmodules | zh-Hant.json | [zdm65477730/ovl-sysmodules](https://github.com/zdm65477730/ovl-sysmodules) | v1.3.2 | ovl-sysmodules.zip | 66f352f29c731c37… |
| sys-clk | zh-Hans.json | [zdm65477730/sys-clk](https://github.com/zdm65477730/sys-clk) | v1.0.2 | sys-clk.zip | 9edbd68bd62ff623… |
| sys-clk | zh-Hant.json | [zdm65477730/sys-clk](https://github.com/zdm65477730/sys-clk) | v1.0.2 | sys-clk.zip | 9edbd68bd62ff623… |
| sys-patch | zh-Hans.json | [zdm65477730/sys-patch](https://github.com/zdm65477730/sys-patch) | v1.6.3.0 | sys-patch.zip | 3683b7a5e25bc9aa… |
| sys-patch | zh-Hant.json | [zdm65477730/sys-patch](https://github.com/zdm65477730/sys-patch) | v1.6.3.0 | sys-patch.zip | 3683b7a5e25bc9aa… |

> 说明：sys-clk / sys-patch / ovl-sysmodules 的 .ovl 在新版本里改了名，
> 语言包目录名随之变化（旧 ovlSysmodules → 新 ovl-sysmodules），安装脚本会自动清理旧文件。

## 校验

每个文件的 sha256 与其所在发布包的 sha256 一致（同一发布包产出）。