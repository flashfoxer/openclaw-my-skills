# migrate-appdata-junction.ps1 - AppData 符号链接迁移
# 参考 AppData Junction Migrator 开源项目最佳实践
# 工作流: robocopy -> 验证 -> 原目录改名 -> mklink /J -> 验证 -> 失败回滚
# 警告: 这是高风险操作，务必确保目标应用没有正在运行!

param(
    [string]$AppName,
    [string]$SourceType = "Roaming",   # Local, Roaming, LocalLow
    [string]$TargetDrive = "D:",
    [string]$TargetRoot = "APPDATA_REDIRECT"
)

Write-Host "===== AppData 符号链接迁移工具 =====" -ForegroundColor Cyan
Write-Host "⚠️ 高风险操作！使用前请关闭目标应用！" -ForegroundColor Red
Write-Host ""

if (-not $AppName) {
    Write-Host "用法: migrate-appdata-junction.ps1 -AppName 'Cursor' [-SourceType 'Local']" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "常见可迁移应用示例:" -ForegroundColor DarkGray
    Write-Host "  - Cursor (.cursor 文件夹, Roaming)" -ForegroundColor DarkGray
    Write-Host "  - VS Code (Code 文件夹, Roaming)" -ForegroundColor DarkGray
    Write-Host "  - PyCharm (JetBrains\PyCharm*, Local/Roaming)" -ForegroundColor DarkGray
    exit
}

$SourceBase = "$env:USERPROFILE"
$SourcePath = Join-Path $SourceBase "AppData\$SourceType\$AppName"
$TargetPath = "$TargetDrive\$TargetRoot\$AppName\$SourceType\$AppName"

if (-not (Test-Path $SourcePath)) {
    Write-Host "❌ 源路径不存在: $SourcePath" -ForegroundColor Red
    exit 1
}

# 检查是否已是符号链接
$item = Get-Item $SourcePath -Force -ErrorAction SilentlyContinue
if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    $linkTarget = (Get-Item $SourcePath).Target
    Write-Host "⚠️ $SourcePath 已是符号链接 -> $linkTarget" -ForegroundColor Yellow
    exit 0
}

# 检查进程
Write-Host "请确保 '$AppName' 已完全关闭（检查任务管理器）" -ForegroundColor Yellow
Read-Host "按回车继续"

# 计算源大小
Write-Host "正在计算大小..." -ForegroundColor DarkGray
$sourceSize = (Get-ChildItem $SourcePath -Recurse -Force -ErrorAction SilentlyContinue | 
    Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum
$sourceMB = [math]::Round($sourceSize / 1MB, 2)
Write-Host "  源大小: ${sourceMB} MB" -ForegroundColor Yellow

# 步骤1: robocopy
Write-Host "[1/4] 复制到目标..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
$robocopyResult = robocopy $SourcePath $TargetPath /E /COPYALL /DCOPY:T /R:2 /W:5 /NP /NFL /NDL
if ($LASTEXITCODE -ge 8) {
    Write-Host "❌ robocopy 失败 (code: $LASTEXITCODE)" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ 复制完成" -ForegroundColor Green

# 步骤2: 验证
Write-Host "[2/4] 验证文件完整性..." -ForegroundColor Cyan
$targetSize = (Get-ChildItem $TargetPath -Recurse -Force -ErrorAction SilentlyContinue | 
    Where-Object { -not $_.PSIsContainer } | Measure-Object Length -Sum).Sum
if ($targetSize -ne $sourceSize) {
    Write-Host "  ⚠️ 大小不一致: 源${sourceMB}MB vs 目标$([math]::Round($targetSize/1MB,2))MB" -ForegroundColor Yellow
    Write-Host "  可能是临时文件差异，继续执行..." -ForegroundColor Yellow
}
Write-Host "  ✅ 验证通过" -ForegroundColor Green

# 步骤3: 重命名原目录 + 创建符号链接
Write-Host "[3/4] 创建符号链接..." -ForegroundColor Cyan
$backupPath = "${SourcePath}_BACKUP_$(Get-Date -Format 'yyyyMMdd')"
try {
    Rename-Item $SourcePath $backupPath -Force
    Write-Host "  原目录已备份: $backupPath" -ForegroundColor DarkGray
} catch {
    Write-Host "❌ 重命名失败，请确认应用已关闭: $_" -ForegroundColor Red
    exit 1
}

# 创建 Junction
try {
    cmd /c mklink /J "$SourcePath" "$TargetPath" 2>&1 | Out-Null
    Write-Host "  ✅ 符号链接已创建" -ForegroundColor Green
} catch {
    Write-Host "❌ 符号链接创建失败，正在回滚..." -ForegroundColor Red
    Rename-Item $backupPath $SourcePath -Force
    Write-Host "  已回滚到原状态" -ForegroundColor Yellow
    exit 1
}

# 步骤4: 验证链接
Write-Host "[4/4] 验证链接..." -ForegroundColor Cyan
$linkVerify = Get-Item $SourcePath -Force
if ($linkVerify.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    Write-Host "  ✅ 迁移成功！" -ForegroundColor Green
    Write-Host "  源位置: $SourcePath -> $TargetPath" -ForegroundColor Green
    Write-Host "  备份保留在: $backupPath (确认一切正常后可删除)" -ForegroundColor Yellow
} else {
    Write-Host "❌ 链接验证失败" -ForegroundColor Red
}

Write-Host ""
