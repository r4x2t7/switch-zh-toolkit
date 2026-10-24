#!/usr/bin/env bash
# 给 Switch 的 Ultrahand/Tesla 覆盖层安装中文语言包。
#   用法:
#     ./install-zh-overlays.sh              # 自动识别 SD 卡
#     ./install-zh-overlays.sh /mnt/sd      # 指定挂载点
#     ./install-zh-overlays.sh --lang-only  # 只装本仓库内的语言包
#
# 本脚本不携带任何第三方二进制，全部从原作者官方发布页下载并校验 SHA-256。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_FILE="$SCRIPT_DIR/sources.json"
WORK_DIR="$(mktemp -d)"
BACKUP_DIR="${TMPDIR:-/tmp}/switch-zh-backup-$(date +%Y%m%d-%H%M%S)"
LANG_ONLY=0
MOUNT=""

for a in "$@"; do
  case "$a" in
    --lang-only) LANG_ONLY=1 ;;
    -*) echo "未知参数: $a" >&2; exit 2 ;;
    *) MOUNT="$a" ;;
  esac
done

step() { printf '\033[36m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32m[OK]\033[0m   %s\n' "$1"; }
warn() { printf '    \033[33m[WARN]\033[0m %s\n' "$1"; }
err()  { printf '    \033[31m[ERR]\033[0m  %s\n' "$1"; }

find_sdcard() {
  if [ -n "$MOUNT" ]; then
    [ -d "$MOUNT" ] || { echo "找不到挂载点 $MOUNT" >&2; exit 1; }
    echo "$MOUNT"; return
  fi
  for d in /mnt/* /media/*/* /Volumes/* /run/media/*/*; do
    [ -d "$d" ] || continue
    [ -f "$d/bootloader/sys/nyx.bin" ] && { echo "$d"; return; }
    if command -v lsblk >/dev/null 2>&1; then :; fi
  done
  # 回退：找卷标为 SWITCH 的分区
  if command -v blkid >/dev/null 2>&1; then
    local lbl
    lbl=$(blkid -t LABEL=SWITCH -o device 2>/dev/null | head -n1 || true)
    [ -n "$lbl" ] && { mountpoint=$(lsblk -no MOUNTPOINT "$lbl" 2>/dev/null | head -n1); [ -n "$mountpoint" ] && { echo "$mountpoint"; return; }; }
  fi
  echo ""
}

copy_with_backup() {
  local sd="$1" src="$2" rel="$3"
  local dst="$sd/$(echo "$rel" | tr '/' '\')"
  if [ -e "$dst" ]; then
    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
    cp -p "$dst" "$BACKUP_DIR/$rel"
    ok "替换 $rel（原文件已备份到 $BACKUP_DIR）"
  else
    mkdir -p "$(dirname "$dst")"
    ok "新增 $rel"
  fi
  cp -p "$src" "$dst"
}

# ---------------------------------------------------------------- 仅语言包
if [ "$LANG_ONLY" = "1" ]; then
  step "仅安装语言包模式"
  SD="$(find_sdcard)"
  [ -n "$SD" ] || { echo "未找到 SD 卡（需含 bootloader/sys/nyx.bin）" >&2; exit 1; }
  ok "SD 卡: $SD"
  count=0
  for d in "$REPO_ROOT"/overlays/*/; do
    name="$(basename "$d")"
    for f in "$d"zh-*.json; do
      [ -e "$f" ] || continue
      copy_with_backup "$SD" "$f" "switch/.overlays/lang/$name/$(basename "$f")"
      count=$((count+1))
    done
  done
  step "完成：安装 $count 个语言包文件"
  exit 0
fi

# ---------------------------------------------------------------- 正常安装
step "定位 SD 卡"
SD="$(find_sdcard)"
[ -n "$SD" ] || { echo "未找到 SD 卡（需含 bootloader/sys/nyx.bin，或卷标 SWITCH）" >&2; exit 1; }
ok "SD 卡: $SD"

mkdir -p "$BACKUP_DIR"

# 用 python 解析 sources.json（无 python 时退回 grep）
json_get() {
  python3 - "$SRC_FILE" "$1" "$2" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
key,idx=sys.argv[2],int(sys.argv[3])
if key=="packages":
    print(d["packages"][idx][sys.argv[3]] if False else "")
PY
}

while IFS=$'\t' read -r NAME URL SHA; do
  [ -n "$NAME" ] || continue
  step "$NAME"
  zip="$WORK_DIR/$NAME.zip"
  if ! curl -fL --silent --show-error -o "$zip" "$URL"; then
    err "下载失败: $URL"; continue
  fi
  got="$(sha256sum "$zip" | cut -d' ' -f1)"
  if [ "$got" != "$SHA" ]; then
    err "SHA-256 不匹配！期望 $SHA 实际 $got —— 已中止该包"; continue
  fi
  ok "下载并校验通过 ($(du -k "$zip" | cut -f1) KB)"
  ex="$WORK_DIR/$NAME"; rm -rf "$ex"; mkdir -p "$ex"
  unzip -q "$zip" -d "$ex"

  # 逐项复制 provides
  python3 - "$SRC_FILE" "$NAME" "$ex" "$SD" "$BACKUP_DIR" <<'PY'
import json,sys,os,shutil,fnmatch
src_file,name,ex,sd,bk=sys.argv[1:6]
d=json.load(open(src_file,encoding='utf-8'))
pkg=next((p for p in d["packages"] if p["name"]==name),None)
if not pkg: raise SystemExit
keep=set(d.get("preserve_user_configs",[]))
blocked_pats=d.get("do_not_touch",[])

# 版本守卫：例如中文 Nyx 只有在卡上现有版本一致时才允许替换
rf=pkg.get("require_file")
if rf:
    rfp=os.path.join(sd,rf.replace('/',os.sep))
    if not os.path.exists(rfp):
        print("    \033[31m[ERR]\033[0m  守卫未通过：卡上缺少 %s，已跳过该包"%rf); raise SystemExit
    with open(rfp,'rb') as f:
        f.seek(int(pkg["require_offset"])); got=f.read(len(pkg["require_bytes"]))
    if got != pkg["require_bytes"].encode('ascii'):
        print("    \033[31m[ERR]\033[0m  守卫未通过：%s 偏移 0x%X 期望 '%s' 实际 '%s'，已跳过该包（版本不匹配，强装会导致启动失败）"
              %(rf,int(pkg["require_offset"]),pkg["require_bytes"],got.decode('ascii','replace'))); raise SystemExit
    print("    \033[32m[OK]\033[0m   版本守卫通过（%s 偏移 0x%X = '%s'）"%(rf,int(pkg["require_offset"]),pkg["require_bytes"]))

for rel in pkg["provides"]:
    # 防线一：绝不碰 CFW 核心 sysmodule
    if any(fnmatch.fnmatch(rel,p) for p in blocked_pats):
        print("    \033[33m[WARN]\033[0m 保护名单，跳过（不改动 CFW 核心）: %s"%rel); continue
    # 防线二：用户已存在的配置文件不覆盖
    if rel in keep and os.path.exists(os.path.join(sd,rel.replace('/',os.sep))):
        print("    \033[33m[WARN]\033[0m 保留用户已有配置，跳过: %s"%rel); continue
    pat=os.path.join(ex,rel.replace('/',os.sep))
    hits=[]
    if os.path.isfile(pat): hits=[pat]
    elif os.path.isdir(pat):
        for dp,dn,fn in os.walk(pat):
            for f in fn: hits.append(os.path.join(dp,f))
    else:
        import glob
        hits=glob.glob(pat)
    if not hits:
        print("    \033[33m[WARN]\033[0m 包内找不到: %s"%rel); continue
    for h in hits:
        target=os.path.relpath(h,ex).replace(os.sep,'/')
        dst=os.path.join(sd,target.replace('/',os.sep))
        if os.path.exists(dst):
            os.makedirs(os.path.dirname(os.path.join(bk,target.replace('/',os.sep))),exist_ok=True)
            shutil.copy2(dst,os.path.join(bk,target.replace('/',os.sep)))
            print("    \033[32m[OK]\033[0m   替换 %s（原文件已备份）"%target)
        else:
            print("    \033[32m[OK]\033[0m   新增 %s"%target)
        os.makedirs(os.path.dirname(dst),exist_ok=True)
        shutil.copy2(h,dst)
PY
done < <(python3 - "$SRC_FILE" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
for p in d["packages"]:
    print("%s\t%s\t%s"%(p["name"],p["url"],p["sha256"]))
PY
)

# 清理被改名取代的旧覆盖层
python3 - "$SRC_FILE" "$SD" "$BACKUP_DIR" <<'PY'
import json,sys,os,shutil
d=json.load(open(sys.argv[1],encoding='utf-8'))
sd,bk=sys.argv[2],sys.argv[3]
for o in d.get("obsolete_overlays",[]):
    p=os.path.join(sd,o["remove"].replace('/',os.sep))
    if os.path.exists(p):
        q=os.path.join(bk,o["remove"].replace('/',os.sep))
        os.makedirs(os.path.dirname(q),exist_ok=True)
        shutil.copy2(p,q); os.remove(p)
        print("    \033[32m[OK]\033[0m   移除旧版 %s（已备份），新版本为 %s"%(o["remove"],o["replaced_by"]))
PY

step "完成"
printf '    备份目录: %s\n' "$BACKUP_DIR"
printf '    \033[32m请安全弹出 SD 卡后重启主机生效。\033[0m\n'
