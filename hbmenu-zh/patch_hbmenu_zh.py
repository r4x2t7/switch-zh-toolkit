#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 hbmenu(nx-hbmenu) 界面切成简体中文。

原理（源码依据 switchbrew/nx-hbmenu v3.6.1）：
  common/text.c      -> s_textLang 永远被设为 SetLanguage_ENUS；系统语言算出来了却没用
  common/language.c  -> g_strings[StrId_Max][17]，每行 17 个语言槽，
                        简体中文(STR_ZH_HANS)的字符串本来就编进了二进制

做法：定位 g_strings 表，把每行「中文槽」的指针复制到「英文槽」。
      零新增数据、零重编译；上游没有中文的行保持英文（textGetString 会回落英文）。
NRO 里的指针存的是「文件内偏移」（加载器再加基址），所以直接搬偏移即可。
"""
import io
import os
import re
import shutil
import struct
import sys

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

BASE = 0x0000000100000000
LANGS = 17
SRC = r"E:\ai coding\pojie\_hekate_zh\downloads\hbmenu_src\nx-hbmenu-3.6.1"


class Nro:
    def __init__(self, path):
        self.data = bytearray(open(path, "rb").read())
        d = self.data
        if bytes(d[8:20]) != b"HOMEBREWNRO0":
            raise ValueError("不是 HOMEBREWNRO0")
        text_size = struct.unpack_from("<I", d, 0x24)[0]
        ro_size = struct.unpack_from("<I", d, 0x2C)[0]
        self.segs = [
            ("text", struct.unpack_from("<I", d, 0x20)[0], text_size, 0),
            ("ro", struct.unpack_from("<I", d, 0x28)[0], ro_size, text_size),
            ("data", struct.unpack_from("<I", d, 0x30)[0],
             struct.unpack_from("<I", d, 0x34)[0], text_size + ro_size),
        ]
        self.ro_lo = self.segs[1][1]
        self.ro_hi = self.segs[1][1] + self.segs[1][2]

    def u64(self, off):
        return struct.unpack_from("<Q", self.data, off)[0]

    def set_u64(self, off, val):
        struct.pack_into("<Q", self.data, off, val)

    def cstr_at(self, off, maxlen=800):
        if off is None or off <= 0 or off >= len(self.data):
            return None
        end = self.data.find(b"\x00", off, off + maxlen)
        if end < 0:
            end = off + maxlen
        return bytes(self.data[off:end]).decode("utf-8", "replace")

    def slot_text(self, off):
        """表项存的是文件内偏移 -> 直接按偏移取字符串。"""
        return self.cstr_at(self.u64(off))

    def find_offsets_of_value(self, val):
        pat = struct.pack("<Q", val)
        out, i = [], self.data.find(pat)
        while i >= 0:
            out.append(i)
            i = self.data.find(pat, i + 1)
        return out

    def save(self, path):
        with open(path, "wb") as f:
            f.write(self.data)


def load_source():
    c = open(os.path.join(SRC, "common", "language.c"), encoding="utf-8", errors="replace").read()
    h = open(os.path.join(SRC, "common", "language.h"), encoding="utf-8", errors="replace").read()
    ids = [x for x in re.findall(r"StrId_(\w+)", h.split("typedef enum", 1)[1].split("}", 1)[0])
           if x != "Max"]

    def grab(blk, macro):
        m = re.search(macro + r"\(\s*((?:\"(?:[^\"\\]|\\.)*\"\s*)+)\)", blk, re.S)
        if not m:
            return None
        s = "".join(re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1)))
        return s.replace("\\n", "\n").replace("\\t", "\t").replace('\\"', '"')

    en, zh = {}, {}
    parts = re.split(r"\[(StrId_\w+)\]\s*=\s*\{", c)
    for i in range(1, len(parts), 2):
        name = parts[i]
        blk = parts[i + 1].split("\n    },")[0]
        en[name] = grab(blk, "STR_EN")
        zh[name] = grab(blk, "STR_ZH_HANS")
    return ids, en, zh


def main():
    src = r"H:\hbmenu.nro"
    work = r"E:\ai coding\pojie\_hekate_zh\hbmenu_zh"
    os.makedirs(work, exist_ok=True)
    dst = os.path.join(work, "hbmenu.nro")
    shutil.copyfile(src, dst)
    nro = Nro(dst)
    ids, en_txt, zh_txt = load_source()
    print("NRO size=%d  ro段 file0x%X..0x%X   StrId=%d" % (len(nro.data), nro.ro_lo, nro.ro_hi, len(ids)))

    en_lit = nro.data.find(en_txt["StrId_Loading"].encode("utf-8"))
    zh_lit = nro.data.find(zh_txt["StrId_Loading"].encode("utf-8"))
    print("EN 'Loading…' 字面量 @0x%X ; ZH '加载中…' 字面量 @0x%X" % (en_lit, zh_lit))

    # 找到 g_strings 表：先定位 EN 指针所在位置，再回退到数组起点
    en_ptr_pos = nro.find_offsets_of_value(en_lit)
    print("指向 EN 字面量的表项位置: %s" % [hex(p) for p in en_ptr_pos])

    table = None
    for p in en_ptr_pos:
        start = p
        while start - 8 >= 0:
            v = nro.u64(start - 8)
            if v == 0 or nro.ro_lo <= v < nro.ro_hi:
                start -= 8
                continue
            break
        # 该起点为数组第 0 行第 0 槽 -> 校验若干行
        ok = True
        for i, nm in enumerate(ids[:8]):
            name = "StrId_" + nm
            if name not in en_txt or en_txt[name] is None:
                continue
            # 找该行的 EN 槽（先假定与第 0 行同列）
            pass
        # 用第 2 行验证列号：找与 en 文本同列的槽
        en_col = None
        for col in range(LANGS):
            slot = start + (2 * LANGS + col) * 8
            if slot + 8 > len(nro.data):
                continue
            if nro.slot_text(slot) == en_txt["StrId_Directory"]:
                en_col = col
                break
        if en_col is None:
            continue
        # 再用第 0 行自身的 EN 槽确认
        if nro.slot_text(start + en_col * 8) != en_txt["StrId_Loading"]:
            continue
        table = (start, en_col)
        break
    assert table, "定位 g_strings 表失败"
    base, en_col = table

    zh_col = None
    for col in range(LANGS):
        if nro.slot_text(base + col * 8) == zh_txt["StrId_Loading"]:
            zh_col = col
            break
    assert zh_col is not None, "定位中文槽失败"
    print("\ng_strings 基址=0x%X  EN列=%d  ZH列=%d" % (base, en_col, zh_col))

    # 全表校验：每行 EN 列都应等于源码里的英文
    bad = []
    for i, nm in enumerate(ids):
        name = "StrId_" + nm
        if name not in en_txt or en_txt[name] is None:
            continue
        got = nro.slot_text(base + (i * LANGS + en_col) * 8)
        if got != en_txt[name]:
            bad.append((name, got, en_txt[name]))
    print("结构校验：%d/%d 行 EN 列与源码一致%s"
          % (len(ids) - len(bad), len(ids), "" if not bad else "  不一致: %s" % bad[:3]))

    # 打补丁
    patched = skipped = 0
    for i in range(len(ids)):
        en_slot = base + (i * LANGS + en_col) * 8
        zh_slot = base + (i * LANGS + zh_col) * 8
        zh_val = nro.u64(zh_slot)
        if zh_val == 0:
            skipped += 1
            continue
        nro.set_u64(en_slot, zh_val)
        patched += 1
    nro.save(dst)
    print("已替换 %d 行；%d 行上游无中文（保持英文）" % (patched, skipped))

    # 验证
    nro2 = Nro(dst)
    ok = tot = 0
    print("\n=== 验证：补丁后各 StrId 显示文本 ===")
    for i, nm in enumerate(ids):
        name = "StrId_" + nm
        if name not in en_txt or en_txt[name] is None:
            continue
        tot += 1
        shown = nro2.slot_text(base + (i * LANGS + en_col) * 8)
        exp_zh = zh_txt.get(name)
        if exp_zh and shown == exp_zh:
            flag = "[中文]"
            ok += 1
        elif shown == en_txt[name]:
            flag = "[英文·上游无中文]"
        else:
            flag = "[??]"
        print("  %-30s %-40s %s" % (name, (shown or "").replace("\n", "⏎")[:40], flag))
    print("\n中文命中 %d / %d" % (ok, tot))
    print("输出: %s" % dst)


if __name__ == "__main__":
    main()
