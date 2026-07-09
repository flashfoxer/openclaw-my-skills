# migrate-wsl-docker.ps1 - WSL/Docker Desktop 数据迁移
# 安全迁移到非系统盘，保留完整功能

param(
    [string]$TargetDrive = "D:",
    [string]$BackupPath = ""
)

Write-Host "===== WSL / Docker 数据迁移工具 =====" -ForegroundColor Cyan
Write-Host ""

# --- Docker Desktop ---
Write-Host "[1/2] Docker Desktop" -ForegroundColor Cyan
$dockerData = "$env:LOCALAPPDATA\Docker\wsl"
if (Test-Path $dockerData) {
    $dockerItems = Get-ChildItem $dockerData -Recurse -Force -ErrorAction SilentlyContinue
    $dockerSize = ($dockerItems | Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum
    $dockerGB = [math]::Round($dockerSize / 1GB, 2)
    Write-Host "  当前 Docker 数据大小: ${dockerGB} GB" -ForegroundColor Yellow
    Write-Host "  路径: $dockerData" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  迁移步骤 (手动操作):" -ForegroundColor Yellow
    Write-Host "  1. Docker Desktop > Settings > Resources > Advanced" -ForegroundColor DarkGray
    Write-Host "  2. Disk image location > 改为 $TargetDrive\Docker\wsl" -ForegroundColor DarkGray
    Write-Host "  3. Docker 会自动移动数据" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  或命令行清理未使用镜像:" -ForegroundColor Green
    Write-Host "  docker system prune -a --volumes" -ForegroundColor DarkGray
} else {
    Write-Host "  Docker Desktop (WSL2后端) 未安装" -ForegroundColor DarkGray
}

Write-Host ""

# --- WSL 发行版 ---
Write-Host "[2/2] WSL 发行版" -ForegroundColor Cyan
try {
    $wslRaw = wsl --list --verbose 2>$null
    if ($wslRaw -and $wslRaw -notmatch "没有安装|Windows Subsystem for Linux has no installed") {
        Write-Host "  已安装的发行版:" -ForegroundColor Cyan
        Write-Host "  $wslRaw" -ForegroundColor DarkGray
        Write-Host ""
        
        $WslTarget = "$TargetDrive\WSL"
        if (-not (Test-Path $WslTarget)) {
            New-Item -ItemType Directory -Path $WslTarget -Force | Out-Null
        }
        
        Write-Host "  迁移方法:" -ForegroundColor Yellow
        Write-Host "  1. 查看发行版名称: wsl --list" -ForegroundColor DarkGray
        Write-Host "  2. 导出发行版:" -ForegroundColor DarkGray
        Write-Host "     wsl --export <发行版名> $WslTarget\backup.tar" -ForegroundColor DarkGray
        Write-Host "  3. 注销原发行版: wsl --unregister <发行版名>" -ForegroundColor DarkGray
        Write-Host "  4. 导入到新位置:" -ForegroundColor DarkGray
        Write-Host "     wsl --import <发行版名> $WslTarget\<发行版名> $WslTarget\backup.tar" -ForegroundColor DarkGray
        Write-Host "  5. 删除备份: Remove-Item $WslTarget\backup.tar" -ForegroundColor DarkGray
    } else {
        Write-Host "  WSL 未安装" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "  WSL 无法查询" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "注意: WSL迁移会删除原发行版，确保已备份重要数据!" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Cyan
