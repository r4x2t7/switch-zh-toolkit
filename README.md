# Switch 中文资源合集

给 Nintendo Switch 自制软件的**中文覆盖层语言包**、**Hekate / Nyx 中文界面资源**，以及把它们装到 SD 卡上的脚本。

> 收录的是 **Ultrahand / Tesla 生态覆盖层（.ovl）** 的简体中文语言包，以及 **Hekate 启动菜单**的中文标签与图标。
> 二进制文件（`.ovl`）不随本仓库分发，安装脚本会从**原作者的官方发布页**下载并校验 SHA-256。

---

## 目录结构

```
overlays/                    各覆盖层的中文语言包（可直接查看 / 修改 / 自行补翻）
  <APPTITLE>/
    zh-Hans.json             简体中文
    zh-Hant.json             繁体中文
  SOURCES.md                 每个文件的来源仓库、发布 tag、资产名与 sha256

install/
  install-zh-overlays.ps1    Windows / PowerShell 安装器
  install-zh-overlays.sh     macOS / Linux 安装器
  sources.json               下载地址与 sha256 清单

hekate-zh/                   Hekate / Nyx 中文界面资源（本仓库自制）
  hekate_ipl_cn.ini          中文启动项配置模板
  icons/                     4 个霓虹风启动项图标（32bit BMP，192x192）
  icons/preview.png          效果预览
  hbmenu_zh.nro              已打好中文补丁的 Homebrew Menu (nx-hbmenu v3.6.1)
  patch_hbmenu_zh.py         上面那个补丁的脚本（可对任意 nx-hbmenu.nro 复现）

docs/
  overlay-lang-mechanism.md  语言包机制与 Hekate 汉化要点（含源码依据）
```

---

## 快速安装

### Windows（PowerShell）

```powershell
# 自动识别卷标为 SWITCH 的 SD 卡
.\install\install-zh-overlays.ps1

# 指定盘符
.\install\install-zh-overlays.ps1 -Drive H:

# 只装语言包，保留你现有的英文 .ovl（想自己再翻几句时用）
.\install\install-zh-overlays.ps1 -LangOnly
```

### macOS / Linux

```bash
chmod +x install/install-zh-overlays.sh
./install/install-zh-overlays.sh            # 自动识别 SD 卡
./install/install-zh-overlays.sh /mnt/sd    # 指定挂载点
./install/install-zh-overlays.sh --lang-only
```

脚本会：**自动定位 SD 卡 → 下载官方汉化包 → 校验 SHA-256 → 备份被替换的旧文件 → 安装 → 打印结果**。

### 手动安装

只要语言包的话，把 `overlays/<APPTITLE>/zh-Hans.json` 复制到 SD 卡：

```
/switch/.overlays/lang/<APPTITLE>/zh-Hans.json
```

`<APPTITLE>` 见 `overlays/SOURCES.md`。**只有覆盖层本体（`.ovl`）支持这套语言包时才会生效**，
纯硬编码英文界面的覆盖层（如 `NX-FanControl`）无法通过语言包汉化。

---

## Hekate / Nyx 中文部分

`hekate-zh/` 是本仓库自制的内容：

- **`hekate_ipl_cn.ini`** —— 中文启动项配置模板。Hekate 的启动项标签直接取自 ini 的段名，
  把段名改成中文即可显示中文（UTF-8 无 BOM + CRLF）。内含四项：
  `破解-虚拟系统` / `Fusee-虚拟系统` / `原生-真实系统` / `破解-真实系统`。

- **`icons/`** —— 4 个 192×192 / 32 位 BMP 启动项图标（霓虹赛博风 Switch 主题）。
  Hekate 会自动去 `bootloader/res/<段名>.bmp` 找图标，所以**不需要改 ini**；
  若用自定义段名，在 ini 里加一行 `icon=bootloader/res/xxx_nobox.bmp` 即可。

装法：

```ini
[破解-虚拟系统]
pkg3=atmosphere/package3
emummcforce=1
icon=bootloader/res/icon_emu_nobox.bmp
```

完整机制（含源码行号）见 [`docs/overlay-lang-mechanism.md`](docs/overlay-lang-mechanism.md)。

### USB 3.0（SuperSpeed）强制开启

`config-samples/atmosphere/system_settings.ini` 是可直接用的配置：

```ini
[usb]
usb30_force_enabled = u8!0x1
```

放到 SD 卡的 `atmosphere/config/system_settings.ini`（该目录不存在就新建），**重启主机生效**。

- 机制：Atmosphère 的 `fusee_setup_horizon` 开机时读这个文件，
  `usb30_force_enabled == "u8!0x1"` 就给 secmon 置 `ForceEnableUsb30`。
  **值必须原样写成 `u8!0x1`**，写成 `1` 不会被识别。
- ⚠️ Atmosphère changelog 明确提示：**开启 USB 3.0 常常会严重影响无线通信**。
  若出现 WiFi 异常，把值改回 `u8!0x0` 即可。
- 硬件前提：主机本体 USB-C 口要有 USB 3.0（T210B01 改款机 / OLED 才有；
  初代 HAC-001 的主机口只有 USB 2.0，需走底座）。
- 怎么确认生效：重启后看 DBI 的 `Speed` 是否变成 SuperSpeed，
  或在 PC 端看该 USB 设备挂到的是不是 xHCI（USB 3.0 根集线器）。


### hbmenu（Homebrew Menu）汉化

`hekate-zh/hbmenu_zh.nro` 是打好中文补丁的 **nx-hbmenu v3.6.1**。

上游其实**编了完整的简体中文语言表**（`common/language.c` 里的 `STR_ZH_HANS`），
但 `common/text.c` 的 `textInit()` 里有一行被注释掉的逻辑，导致 `s_textLang`
被永远锁死成英文：

```c
SetLanguage Language = SetLanguage_ENUS;
s_textLang = Language;                        // ← 先设成英文
rc = setGetSystemLanguage(&s_textLanguageCode);
rc = setMakeLanguage(s_textLanguageCode, &Language);   // ← 系统语言算出来了，但没用
//if (R_SUCCEEDED(rc) && Language < 17) s_textLang = Language;  // ← 被注释掉
```

所以本仓库的做法是：**不重编译，直接把 `g_strings` 表里每行的「中文槽」指针
搬进「英文槽」**（中文串本来就在二进制里），29/38 条变成中文，其余 9 条是上游
在源码里就注释掉的条目，本来也不显示。

- 改动量：**44 字节**（29 个指针槽），零新增数据。
- 用法：把 `hbmenu_zh.nro` 放到 SD 卡根目录，覆盖 `hbmenu.nro`。
- 对任意 nx-hbmenu 复现：`python patch_hbmenu_zh.py`（脚本会自动定位语言表并校验结构）。
- ⚠️ **需要主机系统语言设为中文**：hbmenu 用 `plGetSharedFont()` 按**系统语言**
  加载共享字体（`common/font.c`），系统语言不是中文时字体里没有 CJK 字形，
  中文会显示成方块。


---

## 来源与致谢

- 覆盖层语言包与中文版 `.ovl` 均来自社区汉化作者 **[zdm65477730](https://github.com/zdm65477730)** 的公开发布；
  上游原作者是 **[ppkantorski](https://github.com/ppkantorski)**。
- 各文件的确切来源、发布 tag 与 SHA-256 见 [`overlays/SOURCES.md`](overlays/SOURCES.md)。
- Hekate / Nyx 本身来自 [Atmosphere-NX/Hekate](https://github.com/Atmosphere-NX/Hekate) 与
  [Atmosphere-NX/Atmosphere](https://github.com/Atmosphere-NX/Atmosphere)。

详见 [`NOTICE.md`](NOTICE.md)。
