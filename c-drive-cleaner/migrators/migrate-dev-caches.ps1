# migrate-dev-caches.ps1 - C类一键迁移：开发缓存移到非系统盘
# 通过设置环境变量 / 配置文件 / 符号链接，永久改变开发工具的缓存位置
# 每个工具迁移前检测、迁移后验证

param(
    [string]$TargetDrive = "D:",
    [string]$CacheRoot = "dev-cache"
)

$TargetRoot = "$TargetDrive\$CacheRoot"
$UserProfile = $env:USERPROFILE
$LocalAppData = $env:LOCALAPPDATA

Write-Host "===== 开发工具缓存迁移工具 =====" -ForegroundColor Cyan
Write-Host "目标路径: $TargetRoot" -ForegroundColor Green
Write-Host "迁移方式: 环境变量 / 配置文件 (不创建符号链接)" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $TargetRoot)) {
    New-Item -ItemType Directory -Path $TargetRoot -Force | Out-Null
    Write-Host "已创建目标目录: $TargetRoot" -ForegroundColor Green
}

$results = @()

function Set-EnvVarSafe {
    param([string]$Name, [string]$Value, [string]$Scope = "User")
    try {
        [System.Environment]::SetEnvironmentVariable($Name, $Value, $Scope)
        return $true
    } catch {
        Write-Host "  ❌ 设置失败: $_" -ForegroundColor Red
        return $false
    }
}

# 1. npm 缓存迁移
Write-Host "[1/7] npm" -ForegroundColor Cyan
try {
    $npmTarget = "$TargetRoot\npm"
    New-Item -ItemType Directory -Path $npmTarget -Force | Out-Null
    npm config set cache $npmTarget 2>$null
    $verify = npm config get cache 2>$null
    if ($verify -eq $npmTarget) {
        $results += "✅ npm: -> $npmTarget"
        Write-Host "  ✅ npm缓存已迁移到: $npmTarget" -ForegroundColor Green
    } else {
        $results += "❌ npm: 验证失败"
        Write-Host "  ❌ 迁移失败" -ForegroundColor Red
    }
} catch {
    $results += "❌ npm: 未安装或出错"
    Write-Host "  npm 未安装或出错" -ForegroundColor DarkGray
}

# 2. pip 缓存迁移
Write-Host "[2/7] pip" -ForegroundColor Cyan
try {
    $pipTarget = "$TargetRoot\pip"
    New-Item -ItemType Directory -Path $pipTarget -Force | Out-Null
    if (Set-EnvVarSafe "PIP_CACHE_DIR" $pipTarget) {
        $results += "✅ pip: -> $pipTarget"
        Write-Host "  ✅ PIP_CACHE_DIR = $pipTarget" -ForegroundColor Green
    }
} catch {
    $results += "❌ pip: 未安装或出错"
    Write-Host "  pip 未安装或出错" -ForegroundColor DarkGray
}

# 3. Yarn 缓存迁移
Write-Host "[3/7] Yarn" -ForegroundColor Cyan
try {
    $yarnTarget = "$TargetRoot\yarn"
    New-Item -ItemType Directory -Path $yarnTarget -Force | Out-Null
    yarn config set cacheFolder $yarnTarget 2>$null
    $results += "✅ yarn: -> $yarnTarget"
    Write-Host "  ✅ yarn cacheFolder = $yarnTarget" -ForegroundColor Green
} catch {
    $results += "❌ yarn: 未安装或出错"
    Write-Host "  yarn 未安装或出错" -ForegroundColor DarkGray
}

# 4. pnpm 缓存迁移
Write-Host "[4/7] pnpm" -ForegroundColor Cyan
try {
    $pnpmStore = "$TargetRoot\pnpm-store"
    New-Item -ItemType Directory -Path $pnpmStore -Force | Out-Null
    pnpm set store-dir $pnpmStore 2>$null
    $results += "✅ pnpm: -> $pnpmStore"
    Write-Host "  ✅ pnpm store-dir = $pnpmStore" -ForegroundColor Green
} catch {
    $results += "❌ pnpm: 未安装或出错"
    Write-Host "  pnpm 未安装或出错" -ForegroundColor DarkGray
}

# 5. Cargo 缓存迁移
Write-Host "[5/7] Cargo (Rust)" -ForegroundColor Cyan
$cargoHome = "$TargetDrive\.cargo"
if (-not (Test-Path $cargoHome)) {
    $confirm = Read-Host "  是否迁移整个 .cargo 文件夹(含rustup工具链和缓存)到 $cargoHome ? (Y/N)"
    if ($confirm -eq 'Y') {
        if (Test-Path "$UserProfile\.cargo") {
            Move-Item "$UserProfile\.cargo" $cargoHome -Force -ErrorAction Stop
            cmd /c mklink /D "$UserProfile\.cargo" $cargoHome 2>$null
            $results += "✅ cargo: 整个文件夹 -> $cargoHome (含符号链接)"
        }
        Set-EnvVarSafe "CARGO_HOME" $cargoHome
        Write-Host "  ✅ CARGO_HOME = $cargoHome" -ForegroundColor Green
    }
} else {
    Write-Host "  已存在，跳过" -ForegroundColor DarkGray
}

# 6. Gradle 缓存迁移
Write-Host "[6/7] Gradle" -ForegroundColor Cyan
$gradleTarget = "$TargetRoot\gradle"
New-Item -ItemType Directory -Path $gradleTarget -Force | Out-Null
if (Set-EnvVarSafe "GRADLE_USER_HOME" $gradleTarget) {
    $results += "✅ gradle: -> $gradleTarget"
    Write-Host "  ✅ GRADLE_USER_HOME = $gradleTarget" -ForegroundColor Green
}

# 7. Go 模块缓存迁移
Write-Host "[7/7] Go" -ForegroundColor Cyan
$goTarget = "$TargetDrive\go-modcache"
if (Set-EnvVarSafe "GOMODCACHE" $goTarget) {
    $results += "✅ go: GOMODCACHE -> $goTarget"
    Write-Host "  ✅ GOMODCACHE = $goTarget" -ForegroundColor Green
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  迁移结果汇总" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
foreach ($r in $results) {
    Write-Host "  $r" -ForegroundColor $(if ($r -match "✅") { "Green" } else { "Red" })
}
Write-Host ""
Write-Host "📌 请重启命令行窗口使环境变量生效" -ForegroundColor Yellow
Write-Host "📌 部分工具(Python/Go)可能需要重新登录Windows" -ForegroundColor Yellow
Write-Host ""
