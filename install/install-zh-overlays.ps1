<#
.SYNOPSIS
    给 Switch 的 Ultrahand/Tesla 覆盖层安装中文语言包。

.DESCRIPTION
    自动定位 SD 卡 -> 从原作者官方发布页下载汉化包 -> 校验 SHA-256 -> 备份旧文件 -> 安装。
    本脚本不携带任何第三方二进制。

.PARAMETER Drive
    指定 SD 卡盘符，例如 "H:"。留空则自动识别（找 bootloader\sys\nyx.bin 或卷标 SWITCH）。

.PARAMETER LangOnly
    只安装本仓库内的语言包（switch/.overlays/lang/<APPTITLE>/zh-Hans.json），
    不下载、不替换任何 .ovl。适合想保留英文覆盖层、只补翻几句的人。

.EXAMPLE
    .\install-zh-overlays.ps1
    .\install-zh-overlays.ps1 -Drive H:
    .\install-zh-overlays.ps1 -LangOnly
#>
param(
    [string]$Drive = "",
    [switch]$LangOnly
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$RepoRoot  = Split-Path -Parent $PSScriptRoot
$SrcFile   = Join-Path $PSScriptRoot 'sources.json'
$BackupDir = Join-Path $env:TEMP ("switch-zh-backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$WorkDir   = Join-Path $env:TEMP ("switch-zh-work-" + [guid]::NewGuid().ToString('N').Substring(0, 8))

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    [OK]   $msg" -ForegroundColor Green }
function Write-Warn2($msg){ Write-Host "    [WARN] $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "    [ERR]  $msg" -ForegroundColor Red }

function Find-SdCard {
    param([string]$Hint)
    if ($Hint) {
        $root = $Hint.TrimEnd('\', '/')
        if (-not $root.EndsWith(':')) { $root = $root + ':' }
        $root = $root + '\'
        if (Test-Path $root) { return $root }
        throw "找不到盘符 $Hint"
    }
    foreach ($d in (Get-PSDrive -PSProvider FileSystem)) {
        if ($d.Root -notmatch '^[A-Z]:\\$') { continue }
        if (Test-Path ($d.Root + 'bootloader\sys\nyx.bin')) { return $d.Root }
        $vol = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($d.Name)'" -ErrorAction SilentlyContinue
        if ($vol -and $vol.VolumeName -eq 'SWITCH') { return $d.Root }
    }
    return $null
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLower()
}

function Copy-WithBackup {
    param([string]$SdRoot, [string]$Src, [string]$Rel)
    $dst = Join-Path $SdRoot ($Rel -replace '/', '\')
    if (Test-Path $dst) {
        $bk = Join-Path $BackupDir ($Rel -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $bk) | Out-Null
        Copy-Item -Path $dst -Destination $bk -Force
        Write-Ok ("替换 {0}（原文件已备份到 {1}）" -f $Rel, $BackupDir)
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
        Write-Ok ("新增 {0}" -f $Rel)
    }
    Copy-Item -Path $Src -Destination $dst -Force
}

# ---------------------------------------------------------------- LangOnly
if ($LangOnly) {
    Write-Step "仅安装语言包模式"
    $sd = Find-SdCard -Hint $Drive
    if (-not $sd) { throw "未找到 SD 卡（需包含 bootloader\sys\nyx.bin，或卷标为 SWITCH）" }
    Write-Ok "SD 卡: $sd"
    $ovlLang = Join-Path $RepoRoot 'overlays'
    $count = 0
    foreach ($d in (Get-ChildItem $ovlLang -Directory)) {
        foreach ($f in (Get-ChildItem $d.FullName -Filter 'zh-*.json')) {
            $rel = "switch/.overlays/lang/$($d.Name)/$($f.Name)"
            Copy-WithBackup -SdRoot $sd -Src $f.FullName -Rel $rel
            $count++
        }
    }
    Write-Step "完成：安装 $count 个语言包文件"
    Write-Host "    提示：语言包只对支持该机制的覆盖层生效；纯硬编码英文的覆盖层无法汉化。" -ForegroundColor DarkGray
    return
}

# ---------------------------------------------------------------- 正常安装
Write-Step "定位 SD 卡"
$sd = Find-SdCard -Hint $Drive
if (-not $sd) { throw "未找到 SD 卡（需包含 bootloader\sys\nyx.bin，或卷标为 SWITCH）。可用 -Drive H: 指定。" }
Write-Ok "SD 卡: $sd"

$src = Get-Content $SrcFile -Raw -Encoding UTF8 | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null

foreach ($pkg in $src.packages) {
    Write-Step ("{0}  ({1} {2})" -f $pkg.name, $pkg.repo, $pkg.tag)
    $zip = Join-Path $WorkDir ("$($pkg.name).zip")
    try {
        Invoke-WebRequest -Uri $pkg.url -OutFile $zip -UseBasicParsing -TimeoutSec 180
    } catch {
        Write-Err "下载失败: $($_.Exception.Message)"
        continue
    }
    $got = Get-Sha256 $zip
    if ($got -ne $pkg.sha256) {
        Write-Err "SHA-256 不匹配！期望 $($pkg.sha256) 实际 $got —— 已中止该包"
        continue
    }
    Write-Ok "下载并校验通过 ($([math]::Round((Get-Item $zip).Length/1KB)) KB)"

    # 版本守卫：例如中文 Nyx 只有在卡上现有版本一致时才允许替换
    if ($pkg.require_file) {
        $rf = Join-Path $sd ($pkg.require_file -replace '/', '\')
        if (-not (Test-Path $rf)) {
            Write-Err "守卫未通过：卡上缺少 $($pkg.require_file)，已跳过该包"
            continue
        }
        $bytes = [System.IO.File]::ReadAllBytes($rf)
        $off = [int]$pkg.require_offset
        $exp = [System.Text.Encoding]::ASCII.GetBytes([string]$pkg.require_bytes)
        $got = $bytes[$off..($off + $exp.Length - 1)]
        if (-not [System.Linq.Enumerable]::SequenceEqual([byte[]]$exp, [byte[]]$got)) {
            Write-Err ("守卫未通过：{0} 偏移 0x{1:X} 期望 '{2}' 实际 '{3}'，已跳过该包（版本不匹配，强装会导致启动失败）" -f `
                $pkg.require_file, $off, $pkg.require_bytes,
                ([System.Text.Encoding]::ASCII.GetString([byte[]]$got)))
            continue
        }
        Write-Ok "版本守卫通过（$($pkg.require_file) 偏移 0x$('{0:X}' -f $off) = '$($pkg.require_bytes)'）"
    }

    $ex = Join-Path $WorkDir $pkg.name
    if (Test-Path $ex) { Remove-Item $ex -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $ex -Force

    foreach ($rel in $pkg.provides) {
        # 防线一：绝不碰 CFW 核心 sysmodule（换掉会导致所有游戏都起不来）
        $blocked = $false
        foreach ($pat in $src.do_not_touch) {
            if ($rel -like $pat -or $rel -eq $pat) { $blocked = $true; break }
        }
        if ($blocked) {
            Write-Warn2 "保护名单，跳过（不改动 CFW 核心）: $rel"
            continue
        }
        # 防线二：用户已存在的配置文件不覆盖
        if ($src.preserve_user_configs -contains $rel) {
            $exist = Join-Path $sd ($rel -replace '/', '\')
            if (Test-Path $exist) {
                Write-Warn2 "保留用户已有配置，跳过: $rel"
                continue
            }
        }
        $pattern = $rel -replace '/', '\'
        $files = Get-ChildItem -Path (Join-Path $ex $pattern) -ErrorAction SilentlyContinue
        if (-not $files) {
            $dir = Join-Path $ex ($rel -replace '/', '\')
            $files = @(Get-ChildItem -Path $dir -File -Recurse -ErrorAction SilentlyContinue)
        }
        if (-not $files) { Write-Warn2 "包内找不到: $rel"; continue }
        foreach ($f in $files) {
            $relTarget = $rel -replace '\*.*$', ''
            $relTarget = ($f.FullName.Substring($ex.Length + 1)) -replace '\\', '/'
            Copy-WithBackup -SdRoot $sd -Src $f.FullName -Rel $relTarget
        }
    }
}

# 清理被改名取代的旧覆盖层
foreach ($o in $src.obsolete_overlays) {
    $p = Join-Path $sd ($o.remove -replace '/', '\')
    if (Test-Path $p) {
        $bk = Join-Path $BackupDir ($o.remove -replace '/', '\')
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $bk) | Out-Null
        Copy-Item -Path $p -Destination $bk -Force
        Remove-Item -Path $p -Force
        Write-Ok ("移除旧版 {0}（已备份），新版本为 {1}" -f $o.remove, $o.replaced_by)
    }
}

Write-Step "完成"
Write-Host "    备份目录: $BackupDir" -ForegroundColor DarkGray
Write-Host "    请安全弹出 SD 卡后重启主机生效。" -ForegroundColor Green
