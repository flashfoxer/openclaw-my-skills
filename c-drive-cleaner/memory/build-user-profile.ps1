<#
.SYNOPSIS
    CleanSight v6.2 - User Profile Builder
.DESCRIPTION
    自动识别用户类型、使用习惯，构建个性化画像
.NOTES
    Version: 6.2.0-preview
    Core component of Personalization Engine
#>

param(
    [string]$OutputPath = "$PSScriptRoot\..\memory\user-profile.json",
    [switch]$ForceUpdate
)

$ErrorActionPreference = "Stop"

Write-Host "🧠 CleanSight Profile Builder v6.2" -ForegroundColor Cyan
Write-Host "   正在分析您的使用习惯..." -ForegroundColor Gray

$profile = @{
    schema_version = "1.0.0"
    profile_id = "user-$((Get-Date).ToString('yyyyMMddHHmmss'))"
    created_at = (Get-Date).ToString("o")
    last_updated = (Get-Date).ToString("o")
    
    user_type = @{
        primary = "unknown"
        confidence = 0
        secondary_types = @()
        detection_signals = @{
            dev_tools_installed = $false
            docker_present = $false
            wsl_enabled = $false
            ide_detected = @()
            browser_primary = $null
            special_software = @()
        }
    }
    
    preferences = @{
        scan_mode_preference = "auto"
        preferred_categories = @()
        ignored_categories = @()
        risk_tolerance = "medium"
        output_format = "markdown"
        language = "zh-CN"
        notification_style = "concise"
    }
    
    behavioral_patterns = @{
        typical_session_time = $null
        most_common_triggers = @()
        peak_usage_hours = @()
        cleanup_frequency = "weekly"
        space_threshold_trigger_gb = 10
        repeat_actions = @()
        skipped_recommendations = @()
        accepted_recommendations = @()
    }
    
    learning_insights = @{
        identified_habits = @()
        optimization_opportunities = @()
        warnings_issued = @()
        achievements_unlocked = @()
        personalized_tips = @()
    }
}

Write-Host "`n📊 [1/5] 检测开发环境..." -ForegroundColor Yellow

$devSignals = 0

if (Test-Path "$env:APPDATA\npm") {
    $devSignals++
    $profile.user_type.detection_signals.dev_tools_installed = $true
    Write-Host "   ✅ 检测到 Node.js/npm" -ForegroundColor Green
}

if (Test-Path "$env:LOCALAPPDATA\pip") {
    $devSignals++
    $profile.user_type.detection_signals.dev_tools_installed = $true
    Write-Host "   ✅ 检测到 Python/pip" -ForegroundColor Green
}

if (Test-Path "$env:USERPROFILE\.cargo") {
    $devSignals++
    $profile.user_type.detection_signals.dev_tools_installed = $true
    Write-Host "   ✅ 检测到 Rust/Cargo" -ForegroundColor Green
}

if (Get-Command docker -ErrorAction SilentlyContinue) {
    $devSignals += 2
    $profile.user_type.detection_signals.docker_present = $true
    $profile.user_type.detection_signals.special_software += "Docker"
    Write-Host "   ✅ 检测到 Docker" -ForegroundColor Green
}

if (Get-Command wsl -ErrorAction SilentlyContinue) {
    $devSignals++
    $profile.user_type.detection_signals.wsl_enabled = $true
    $profile.user_type.detection_signals.special_software += "WSL"
    Write-Host "   ✅ 检测到 WSL" -ForegroundColor Green
}

$ideList = @(
    @{name="VS Code"; path="$env:LOCALAPPDATA\Programs\Microsoft VS Code"},
    @{name="JetBrains"; path="$env:APPDATA\JetBrains"},
    @{name="Visual Studio"; path="${env:ProgramFiles(x86)}\Microsoft Visual Studio"},
    @{name="Android Studio"; path="$env:LOCALAPPDATA\Android"}
)

foreach ($ide in $ideList) {
    if (Test-Path $ide.path) {
        $profile.user_type.detection_signals.ide_detected += $ide.name
        $devSignals++
        Write-Host "   ✅ 检测到 $($ide.name)" -ForegroundColor Green
    }
}

Write-Host "`n🌐 [2/5] 分析浏览器使用..." -ForegroundColor Yellow

$browsers = @(
    @{name="Chrome"; path="$env:LOCALAPPDATA\Google\Chrome\User Data"},
    @{name="Edge"; path="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},
    @{name="Firefox"; path="$env:APPDATA\Mozilla\Firefox\Profiles"}
)

foreach ($browser in $browsers) {
    if (Test-Path $browser.path) {
        if (-not $profile.user_type.detection_signals.browser_primary) {
            $profile.user_type.detection_signals.browser_primary = $browser.name
            Write-Host "   🌐 主力浏览器: $($browser.name)" -ForegroundColor Cyan
        } else {
            Write-Host "   📦 额外安装: $($browser.name)" -ForegroundColor Gray
        }
    }
}

Write-Host "`n🎯 [3/5] 确定用户类型..." -ForegroundColor Yellow

if ($devSignals -ge 5) {
    $profile.user_type.primary = "devops_engineer"
    $profile.user_type.confidence = 85
    $profile.preferences.preferred_categories = @("C", "G", "F")
    $profile.behavioral_patterns.cleanup_frequency = "biweekly"
    Write-Host "   🎖️  用户类型: DevOps 工程师 (置信度: 85%)" -ForegroundColor Magenta
    Write-Host "      特征: 重度开发者 + 容器化环境" -ForegroundColor Gray
    
} elseif ($devSignals -ge 3) {
    $profile.user_type.primary = "developer"
    $profile.user_type.confidence = 75
    $profile.preferences.preferred_categories = @("C", "B", "D")
    $profile.behavioral_patterns.cleanup_frequency = "weekly"
    Write-Host "   💻 用户类型: 开发者 (置信度: 75%)" -ForegroundColor Blue
    Write-Host "      特征: 常规开发环境，多语言栈" -ForegroundColor Gray
    
} elseif ($devSignals -ge 1) {
    $profile.user_type.primary = "tech_savvy"
    $profile.user_type.confidence = 60
    $profile.preferences.preferred_categories = @("B", "D", "L")
    $profile.behavioral_patterns.cleanup_frequency = "monthly"
    Write-Host "   🔧 用户类型: 技术爱好者 (置信度: 60%)" -ForegroundColor Yellow
    Write-Host "      特征: 有一定技术背景，轻度开发需求" -ForegroundColor Gray
    
} else {
    $profile.user_type.primary = "general_user"
    $profile.user_type.confidence = 70
    $profile.preferences.preferred_categories = @("B", "D", "L", "F")
    $profile.behavioral_patterns.cleanup_frequency = "monthly"
    Write-Host "   👤 用户类型: 普通用户 (置信度: 70%)" -ForegroundColor Green
    Write-Host "      特征: 日常办公/娱乐，关注易用性" -ForegroundColor Gray
}

Write-Host "`n⚙️  [4/5] 生成个性化配置..." -ForegroundColor Yellow

switch ($profile.user_type.primary) {
    "devops_engineer" {
        $profile.preferences.scan_mode_preference = "custom"
        $profile.preferences.risk_tolerance = "high"
        $profile.preferences.notification_style = "detailed"
        $profile.behavioral_patterns.space_threshold_trigger_gb = 20
        
        $profile.learning_insights.personalized_tips = @(
            "建议关注 Docker 镜像和 WSL 分区的空间占用",
            "可设置定时任务每周清理 npm/pip 缓存",
            "考虑将大型项目迁移到非系统盘"
        )
    }
    "developer" {
        $profile.preferences.scan_mode_preference = "quick"
        $profile.preferences.risk_tolerance = "medium"
        $profile.preferences.notification_style = "balanced"
        $profile.behavioral_patterns.space_threshold_trigger_gb = 15
        
        $profile.learning_insights.personalized_tips = @(
            "推荐使用快速扫描模式，重点关注开发缓存",
            "npm/pip 缓存可以安全清理，但建议在项目间确认",
            "IDE 缓存清理后首次启动会变慢，属于正常现象"
        )
    }
    "tech_savvy" {
        $profile.preferences.scan_mode_preference = "standard"
        $profile.preferences.risk_tolerance = "medium-low"
        $profile.preferences.notification_style = "concise"
        $profile.behavioral_patterns.space_threshold_trigger_gb = 10
        
        $profile.learning_insights.personalized_tips = @(
            "标准扫描模式适合您的使用场景",
            "浏览器缓存是安全的清理目标",
            "定期清理临时文件可保持系统流畅"
        )
    }
    default {
        $profile.preferences.scan_mode_preference = "auto"
        $profile.preferences.risk_tolerance = "low"
        $profile.preferences.notification_style = "friendly"
        $profile.behavioral_patterns.space_threshold_trigger_gb = 10
        
        $profile.learning_insights.personalized_tips = @(
            "建议使用智能模式，让 AI 为您选择最佳策略",
            "优先清理临时文件和浏览器缓存（最安全）",
            "不确定的操作先询问，不要急于执行"
        )
    }
}

Write-Host "`n💾 [5/5] 保存用户画像..." -ForegroundColor Yellow

$profileJson = $profile | ConvertTo-Json -Depth 10
Set-Content -Path $OutputPath -Value $profileJson -Encoding UTF8

Write-Host "`n✅ 用户画像生成完成！" -ForegroundColor Green
Write-Host "   📄 保存位置: $OutputPath" -ForegroundColor Cyan
Write-Host "" 
Write-Host "📋 画像摘要:" -ForegroundColor White
Write-Host "   ┌─────────────────────────────────┐" -ForegroundColor Gray
Write-Host "   │ 用户类型: $($profile.user_type.primary.PadRight(23))│" -ForegroundColor White
Write-Host "   │ 置信度:   $($($profile.user_type.confidence.ToString() + '%').PadRight(23))│" -ForegroundColor White
Write-Host "   │ 推荐模式: $($profile.preferences.scan_mode_preference.PadRight(23))│" -ForegroundColor White
Write-Host "   │ 风险承受: $($profile.preferences.risk_tolerance.PadRight(23))│" -ForegroundColor White
Write-Host "   │ 关注类别: $($($profile.preferences.preferred_categories -join ', ').PadRight(23))│" -ForegroundColor White
Write-Host "   └─────────────────────────────────┘" -ForegroundColor Gray

Write-Host ""
Write-Host "💡 下次使用时，CleanSight 将基于此画像提供个性化建议。" -ForegroundColor Yellow

return $profile