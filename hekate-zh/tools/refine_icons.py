#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""霓虹风图标精修 v3（针对"整块 app 图标"型 AI 原图）：

   1) 若四角是白底 -> 说明 AI 把图标画在白纸上：把"与画面边缘连通的白色"抠成透明，
      裁到图标本体边界（图标自带的圆角保留，不二次倒角）
   2) 否则为整幅出血图：直接裁方形 + 施加统一圆角遮罩（与其他图标风格统一）
   3) 输出 192x192 / 32bit BMP（BGRA / 自下而上）+ PNG 预览
"""
import io
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")
OUT = os.path.join(BASE, "out")
PREVIEW = os.path.join(BASE, "preview")
os.makedirs(OUT, exist_ok=True)
os.makedirs(PREVIEW, exist_ok=True)

S, RADIUS = 192, 42

ITEMS = [
    # 启动项,              原图,                     输出名
    ("CFW - emuMMC",         "neon_switch_emu.jpg",     "icon_emu_nobox"),
    ("CFW - emuMMC (Fusee)", "neon_switch_fusee.jpg",   "icon_fusee_nobox"),
    ("Stock - SYSNAND",      "neon_switch_stock.jpg",   "icon_stock_nobox"),
    ("CFW - SYSNAND",        "neon_switch_sysnand.jpg", "icon_sysnand_nobox"),
]


def white_border_mask(img, thr=232):
    """把与画面边缘连通的近白区域标记为背景。返回 L 图（255=背景）。"""
    m = Image.new("L", img.size, 0)
    px = img.convert("RGB").load()
    mp = m.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if min(r, g, b) > thr:
                mp[x, y] = 255
    # 从四角泛洪
    for corner in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)]:
        if mp[corner] == 255:
            ImageDraw.floodfill(m, corner, 128, thresh=0)
    return m.point(lambda v: 255 if v == 128 else 0)


def rounded_mask(size, radius):
    m = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1],
                                        radius=radius * 4, fill=255)
    return m.resize((size, size), Image.LANCZOS)


def write_bmp32(path, rgba):
    w, h = rgba.size
    raw = rgba.tobytes()
    rows = [raw[y * w * 4:(y + 1) * w * 4] for y in range(h)][::-1]   # BMP 自下而上
    body = b"".join(rows)
    px = bytearray()
    for i in range(0, len(body), 4):
        px += bytes((body[i + 2], body[i + 1], body[i], body[i + 3]))  # RGBA -> BGRA
    image_size = len(px)
    fh = b"BM" + struct.pack("<IHHI", 54 + image_size, 0, 0, 54)
    ih = struct.pack("<IiiHHIIiiII", 40, w, h, 1, 32, 0, image_size, 2835, 2835, 0, 0)
    with open(path, "wb") as f:
        f.write(fh + ih + bytes(px))


made = []
for label, src, outname in ITEMS:
    p_src = os.path.join(RAW, src)
    im = Image.open(p_src).convert("RGB")

    # 角落判定：是否白底
    corners = [im.getpixel(p) for p in [(0, 0), (im.width - 1, 0), (0, im.height - 1), (im.width - 1, im.height - 1)]]
    on_white = all(min(c) > 225 for c in corners)
    print("%-24s 四角=%s  => %s" % (label, corners, "白底图标(保留自带圆角)" if on_white else "出血图(施加统一圆角)"))

    work = im.resize((1024, 1024), Image.LANCZOS)
    if on_white:
        bgmask = white_border_mask(work)
        rgba = work.convert("RGBA")
        rgba.putalpha(Image.eval(bgmask, lambda v: 255 - v))
        bbox = rgba.getbbox()
        if bbox:
            # 裁到图标本体，补成正方形
            x0, y0, x1, y1 = bbox
            cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
            side = max(x1 - x0, y1 - y0)
            side = int(side * 1.01)
            l = max(0, min(cx - side // 2, 1024 - side))
            t = max(0, min(cy - side // 2, 1024 - side))
            rgba = rgba.crop((l, t, l + side, t + side))
    else:
        rgba = work.convert("RGBA")

    out = rgba.resize((S, S), Image.LANCZOS)
    if not on_white:
        out.putalpha(rounded_mask(S, RADIUS))

    png = os.path.join(OUT, "%s.png" % outname)
    out.save(png)
    bmp = os.path.join(OUT, "%s.bmp" % outname)
    write_bmp32(bmp, out)
    made.append((label, png, bmp))
    print("   -> %s.bmp" % outname)

# 预览（带中文标签）
try:
    from PIL import ImageFont
    fnt = ImageFont.truetype(r"C:\Windows\Fonts\msyh.ttc", 21)
except Exception:
    fnt = None
sheet = Image.new("RGB", (S * len(made) + 40 * (len(made) + 1), S + 120), (0x2D, 0x2D, 0x2D))
d = ImageDraw.Draw(sheet)
CN_LABEL = {"CFW - emuMMC": "破解-虚拟NAND", "CFW - emuMMC (Fusee)": "破解-Fusee引导",
            "Stock - SYSNAND": "原生-实体NAND", "CFW - SYSNAND": "破解-实体NAND"}
for i, (label, png, bmp) in enumerate(made):
    im = Image.open(png).convert("RGBA")
    x = 40 + i * (S + 40)
    sheet.paste(im, (x, 40), im)
    d.text((x, 40 + S + 14), CN_LABEL.get(label, label), fill=(0xD8, 0xD8, 0xD8), font=fnt)
p = os.path.join(PREVIEW, "icons_sheet_neon.png")
sheet.save(p)
print("预览:", p)
