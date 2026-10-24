# Hekate / Nyx 中文资源

本目录是**本仓库自制**的部分：Hekate 启动菜单的中文标签配置与启动项图标。

## hekate_ipl_cn.ini

Hekate 的启动项标签直接取自 `bootloader/hekate_ipl.ini` 的**段名**，
所以中文标签只需要改段名。四个启动项对应：

| 段名 | 原本 | 作用 |
|---|---|---|
| `破解-虚拟系统` | CFW - emuMMC | 大气层 CFW，跑在 SD 卡模拟的 NAND（emuMMC）上 |
| `Fusee-虚拟系统` | CFW - emuMMC (Fusee) | 同上，但走 fusee 引导链（保底用） |
| `原生-真实系统` | Stock - SYSNAND | 官方未破解系统，跑在机载 eMMC 上 |
| `破解-真实系统` | CFW - SYSNAND | 大气层 CFW，跑在机载 eMMC 上 |

用法：把本文件复制到 SD 卡的 `bootloader/hekate_ipl.ini`
（建议先备份原文件），重启 Hekate 生效。

**格式要求**：UTF-8 **无 BOM**、CRLF 行尾。段名的 UTF-8 字节数控制在 22 以内
（Hekate 超过就会启用滚动文本）。

## icons/

4 个 192×192 / 32 位 BMP 启动项图标，霓虹赛博风 Switch 主题：

| 文件 | 对应启动项 |
|---|---|
| `icon_emu_nobox.bmp` | 破解-虚拟系统（蓝青，全息 Switch） |
| `icon_fusee_nobox.bmp` | Fusee-虚拟系统（橙红，闪电） |
| `icon_stock_nobox.bmp` | 原生-真实系统（银灰，原厂 Switch） |
| `icon_sysnand_nobox.bmp` | 破解-真实系统（紫蓝，芯片） |

`preview.png` 是模拟 Hekate 深色底（`themebg=2d2d2d`）的效果预览。

### 安装

**方式一（推荐，不用改 ini）**：把 BMP 复制到 SD 卡的 `bootloader/res/`，
文件名 = **ini 里的段名** + `.bmp`。例如段名是 `破解-虚拟系统`，
则文件名为 `bootloader/res/破解-虚拟系统.bmp`。
（Hekate 会自动按段名找图标，`gui.c:1775`。）

**方式二（显式指定）**：在 ini 的对应段里加一行 `icon=`，例如：

```ini
[破解-虚拟系统]
pkg3=atmosphere/package3
emummcforce=1
icon=bootloader/res/icon_emu_nobox.bmp
```

文件名带 `_nobox` 后缀表示**不去掉 Hekate 默认的边框样式**，保留原色；
带 `_hue` 后缀则会被染成主题色。

### 格式细节（照着做不会翻车）

- 必须 **32 位 BMP**、BM 开头、数据偏移 54，像素按 **BGRA** 存。
- **alpha 有效**，圆角靠它（`Rounded` 半径建议 42/192）。
- BMP 是**自下而上**存储，但写文件时要用 Pillow/标准库正常输出，**不要按字节整体反转**
  （Hekate 读的时候会按行翻转）。按字节反转出来的文件头部长得完全正常，只有逐像素比对才发现是乱的。

## 关于 Hekate 界面本身

Hekate 主界面（Home / Tools / Console Info）的语言是**编译进 `bootloader/sys/nyx.bin`** 的，
改文件无效，需要换整个 `nyx.bin`，且版本必须匹配（详见
[`../docs/overlay-lang-mechanism.md`](../docs/overlay-lang-mechanism.md)）。
