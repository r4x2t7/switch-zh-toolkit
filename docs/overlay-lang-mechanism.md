# 覆盖层语言包机制 与 Hekate 汉化要点

本文记录的都是**从源码读出来的硬事实**，并附出处，方便自己二次开发或给别的插件补翻译。

---

## 一、Ultrahand / Tesla 系覆盖层（`.ovl`）的语言包

### 1. 语言包放在哪

覆盖层在启动时按这个路径找语言文件（`ovl-sysmodules` 源码 `source/gui_main.cpp:151`）：

```cpp
std::string lanPath = std::string("sdmc:/switch/.overlays/lang/") + APPTITLE + "/";
tsl::tr::InitTrans(lanPath, jsonStr);
```

即：

```
SD:/switch/.overlays/lang/<APPTITLE>/<语言代码>.json
```

- `<APPTITLE>` 是**插件自己定义的标题名**，来自其 `Makefile` 的 `APP_TITLE`
  （例：`ovl-sysmodules` 的 `Makefile` 里 `APP_TITLE := ovl-sysmodules`），
  **不等于 `.ovl` 文件名**。这也是为什么同一款插件在新版里文件名会变：
  `ovlSysmodules.ovl` → `ovl-sysmodules.ovl`，语言包目录也跟着从
  `lang/ovlSysmodules/` 变成 `lang/ovl-sysmodules/`。
- 语言文件名用 `zh-Hans.json`（简体）/ `zh-Hant.json`（繁体）。

### 2. 语言文件是什么格式

**扁平 JSON：英文键 → 中文值**。没有嵌套，键名就是代码里的英文标识符。

```json
{
  "PluginName": "系统模块",
  "PowerCategoryHeaderText": "SWITCH电源控制  |    重启和关机",
  "PowerResetListItemKey": "重启",
  "SysmodulesNotFoundScanOKCustomDrawerText": "没有找到任何系统模块！"
}
```

- 键在语言包里找不到 → **回落显示内置英文**（所以可以只翻一半）。
- 值里可以带 `\uE0xx` 这样的图标码（LVGL 符号字体）。

### 3. 哪些覆盖层能用这套机制

判据：二进制里能找到 `lang/` 与 `.json` 字符串，且源码里有 `tsl::tr::InitTrans` 调用。

| 覆盖层 | 支持外部语言包 |
|---|---|
| ovlmenu（Ultrahand） | ✅（但走的是另一套，见下） |
| ovl-sysmodules | ✅ |
| FPSLocker | ✅ |
| ReverseNX-RT | ✅ |
| QuickNTP | ✅ |
| sys-clk | ✅ |
| sys-patch | ✅ |
| EdiZon | ✅ |
| NX-FanControl | ❌ 界面文案硬编码在 `overlay/source/main_menu.cpp` 里，无语言包钩子 |

### 4. ovlmenu / Ultrahand 走的是另一套

Ultrahand 不用上面那套，而是：

```
SD:/config/ultrahand/lang/<locale>.json      （en / zh-cn / zh-tw / ja / ko / de ...）
```

语言由 `SD:/config/ultrahand/config.ini` 里的 `default_lang=zh-cn` 决定。
（`ovlmenu` 源码里能看到的 `default_lang` / `json_file_source` / `json_file` 等键。）

### 5. 覆盖层的其它约定

- 配置文件：`SD:/config/<APPTITLE>/config.ini`（同样是 `APPTITLE`，不是文件名）。
  例：`config/ovl-sysmodules/config.ini`、`config/QuickNTP/config.ini`。
- sysmodule 侧：系统模块放在 `SD:/atmosphere/contents/<TID>/exefs.nsp`，
  再用 `SD:/atmosphere/contents/<TID>/flags/boot2.flag` 标记「在 boot2 阶段加载」
  （Atmosphère 官方文档 `docs/features/configurations.md`）。
  没有 `boot2.flag` 的内容只会在对应程序启动时才被当作进程覆盖加载。

---

## 二、Hekate / Nyx 的汉化

### 1. Nyx 界面语言是编译进 `nyx.bin` 的

Hekate 的 GUI 是个独立载荷 `bootloader/sys/nyx.bin`。要汉化界面，得换整个 `nyx.bin`，
不能只改某个文件。

**版本必须严格对应**，Hekate 会在 `bootloader/main.c` 里比对（`NYX_VER_OFF = 0x9C`）：

```c
u32 expected_nyx_ver = ((NYX_VER_MJ+'0')<<24)|((NYX_VER_MN+'0')<<16)|((NYX_VER_HF+'0')<<8);
u32 nyx_ver = byte_swap_32(*(u32*)(nyx + 0x9C)) & 0xFFFFFF00;
if (nyx_ver < expected_nyx_ver) {   // 只拦"比自身更旧"的
    WPRINTF("Old Nyx GUI found! There will be dragons!\n");
}
```

- 注意判定是 **`<`（更旧才拦）**，所以装更新的 Nyx 不会报错；装更旧的会被警告。
- 版本字在载荷偏移 `0x9C`，是 4 字节小端。
- ⚠️ 别被文件里出现 `NYX1.8.0` 误导 —— 那是 **SD 卡 FAT32 引导扇区的 OEM 名**
  （Atmosphère `bdk/libs/fatfs/ff.c` 里写死的 `"\xEB\xFE\x90" "NYX1.8.0"`），**不是载荷版本**。
  真正的版本要从 `0x9C` 解。

### 2. 启动项标签 = ini 段名

`nyx/nyx_gui/frontend/gui.c:1893`：

```c
lv_label_set_text(launch_ctxt.label[curr_btn_idx], ini_sec->name);
```

所以把 `bootloader/hekate_ipl.ini` 的段名写成中文即可显示中文。注意事项：

- ini 解析（`bdk/utils/ini.c`）是**字节透传**，`[名字]` 原样保存 → UTF-8 中文可用。
- 文件必须 **UTF-8 无 BOM**（BOM 会让首行不以 `[` 开头，`[config]` 段就废了）。
- 行尾用 CRLF（Atmosphère 的 FatFs 配了 `FF_USE_STRFCUNC 2`，会去 `\r`）。
- 段名 **UTF-8 字节数 > 22** 时 Hekate 会启用滚动文本（`gui.c:1897`），
  所以中文段名别太长（4 个汉字 + ASCII 约 17~19 字节比较稳）。
- 段名叫 `config` 会被当成全局配置段，不是启动项。

### 3. 启动项图标

`gui.c:1771-1800` 的查找顺序（没有显式 `icon=` 键时）：

```
bootloader/res/<段名>.bmp
bootloader/res/<段名>_hue_nobox.bmp     套主题色 + 无边框
bootloader/res/<段名>_hue.bmp            套主题色
bootloader/res/<段名>_nobox.bmp          无边框，保留原色
```

显式写 `icon=bootloader/res/xxx.bmp` 时，**后缀规则依然生效**（`gui.c:1815-1828`）。
内置图标是「白色剪影 + 透明底」，再被染成主题色；想保留自己的彩色就用 `_nobox` 后缀。

**格式要求**（`gui.c:651-734` 的解码器）：

- 必须是 **32 位 BMP**（`bitmap[28] == 32`），`BM` 开头，数据偏移一般 54。
- 像素按 **BGRA** 存储（LVGL 的 ARGB8888 小端序），**alpha 有效**（圆角靠它）。
- BMP 自下而上存储，Hekate 读的时候会做上下翻转 —— 所以**别自己按字节整体反转**，
  要按**行**倒序，否则画面会是乱的（头部长得完全合法，只有像素级比对才能发现）。

### 4. 图标 / 启动项的中文命名建议

| 英文 | 中文 | 字节数 |
|---|---|---|
| CFW - emuMMC | 破解-虚拟系统 | 19 |
| CFW - emuMMC (Fusee) | Fusee-虚拟系统 | 18 |
| Stock - SYSNAND | 原生-真实系统 | 19 |
| CFW - SYSNAND | 破解-真实系统 | 19 |

（`虚拟` = emuMMC，SD 卡模拟 NAND；`真实` = sysMMC，机载 eMMC。）

---

## 三、其它实测结论

- `bootloader/atmosphere/contents/<TID>/` 是 **Kosmos 时代**的 boot2 链路径，
  Atmosphère 1.x 与 Hekate 6.x 都**不再读取**它。放在那儿只是死文件，容易误导排查。
- Atmosphère 官方 sysmodule 在 `atmosphere/stratosphere.romfs/atmosphere/contents/<PID>/exefs.nsp`
  （PID 如 `0100000000000008` = boot2），不在 SD 卡上。
- 自定义 sysmodule 的版本闸门由模块自己实现（例如 SaltyNX 会检查 Atmosphère 版本）。
- Atmosphère 1.10.0 起修改了 userland↔kernel 的 TLS ABI，
  **老 homebrew 需要用 libnx ≥ 4.10.0 重编**，否则会崩（常见崩在 hbloader）。
