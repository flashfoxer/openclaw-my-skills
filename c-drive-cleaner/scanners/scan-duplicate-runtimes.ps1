# scan-duplicate-runtimes.ps1 - J类：重复运行时检测(增强版)
# 只读扫描 — 自动发现Electron/CEF应用，识别具体应用名称和运行时占比

if (-not (Get-Command "Get-FolderSizeFast" -ErrorAction SilentlyContinue)) { . (Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) "_common.ps1") }

Write-Host "===== J类：重复运行时(Electron/CEF)检测 =====" -ForegroundColor Cyan

$scanRoots = @(
    @{ Path = "$env:LOCALAPPDATA"; Label = "LocalAppData" },
    @{ Path = "$env:APPDATA"; Label = "AppData\Roaming" },
    @{ Path = "${env:ProgramFiles(x86)}"; Label = "Program Files (x86)" },
    @{ Path = "$env:ProgramFiles"; Label = "Program Files" }
)

$electronApps = [System.Collections.ArrayList]::new()
$cefIndicators = @("libcef.dll", "chrome_elf.dll", "v8_context_snapshot.bin")
$pakPattern = "*.pak"

function Get-AppIdentity {
    param([string]$DirPath)
    $pkgJson = Join-Path $DirPath "package.json"
    if (Test-Path $pkgJson) {
        try {
            $pkg = Get-Content $pkgJson -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($pkg.productName) { return $pkg.productName }
            if ($pkg.name) { return $pkg.name }
        } catch {}
    }
    $exes = Get-ChildItem $DirPath -Recurse -Filter "*.exe" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '^(uninstall|setup|update|crash_reporter)' } |
        Select-Object -First 3
    if ($exes) {
        $exeNames = ($exes | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) }) -join ", "
        return $exeNames
    }
    return ""
}

function Measure-RuntimeSize {
    param([string]$DirPath)
    $runtimePatterns = @(
        "libcef.dll", "chrome_elf.dll", "v8_context_snapshot.bin",
        "*.pak", "d3dcompiler_*.dll", "vk_swiftshader*.dll",
        "libEGL.dll", "libGLESv2.dll", "swiftshader"
    )
    $runtimeSize = 0L
    $dataSize = 0L

    foreach ($pattern in $runtimePatterns) {
        $files = Get-ChildItem $DirPath -Recurse -Filter $pattern -File -ErrorAction SilentlyContinue
        foreach ($f in @($files)) {
            $runtimeSize += $f.Length
        }
    }

    $allFiles = Get-ChildItem $DirPath -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in @($allFiles)) {
        $dataSize += $f.Length
    }
    $nonRuntime = $dataSize - $runtimeSize

    return @{ RuntimeMB = [math]::Round($runtimeSize / 1MB, 1); DataMB = [math]::Round($nonRuntime / 1MB, 1); TotalMB = [math]::Round($dataSize / 1MB, 1) }
}

foreach ($root in $scanRoots) {
    if (-not (Test-Path $root.Path)) { continue }
    $dirs = Get-ChildItem $root.Path -Directory -ErrorAction SilentlyContinue
    foreach ($dir in $dirs) {
        $hasCef = $false
        foreach ($indicator in $cefIndicators) {
            if (Get-ChildItem $dir.FullName -Recurse -Filter $indicator -File -ErrorAction SilentlyContinue |
                Select-Object -First 1) {
                $hasCef = $true
                break
            }
        }
        if (-not $hasCef) { continue }
        $pakFiles = Get-ChildItem $dir.FullName -Recurse -Filter $pakPattern -File -ErrorAction SilentlyContinue
        if ($pakFiles.Count -ge 3) {
            $r = Get-FolderSizeFast $dir.FullName
            $identity = Get-AppIdentity -DirPath $dir.FullName
            $sizes = Measure-RuntimeSize -DirPath $dir.FullName
            $parentDir = if ($dir.Parent) { $dir.Parent.Name } else { "" }
            [void]$electronApps.Add([PSCustomObject]@{
                DirName   = $dir.Name
                Identity  = $identity
                Parent    = $parentDir
                RootLabel = $root.Label
                Path      = $dir.FullName
                Size      = $r.Size
                PakCount  = $pakFiles.Count
                RuntimeMB = $sizes.RuntimeMB
                DataMB    = $sizes.DataMB
                TotalMB   = $sizes.TotalMB
            })
        }
    }
}

if ($electronApps.Count -eq 0) {
    Write-Host "  ○ 未发现Electron/CEF应用" -ForegroundColor DarkGray
} else {
    $totalSize = ($electronApps | Measure-Object Size -Sum).Sum
    $totalGB = [math]::Round($totalSize / 1GB, 2)
    $totalRuntimeMB = ($electronApps | Measure-Object RuntimeMB -Sum).Sum
    $totalDataMB = ($electronApps | Measure-Object DataMB -Sum).Sum

    Write-Host "  发现 $($electronApps.Count) 个Electron/CEF应用，总占用 $totalGB GB" -ForegroundColor Yellow
    Write-Host "  运行时总计 ~$([math]::Round($totalRuntimeMB/1024,1)) GB | 数据总计 ~$([math]::Round($totalDataMB/1024,1)) GB" -ForegroundColor Yellow
    Write-Host ""

    $sorted = $electronApps | Sort-Object Size -Descending
    foreach ($app in $sorted) {
        $sizeStr = if ($app.Size -ge 1GB) { "$([math]::Round($app.Size/1GB,2)) GB" } else { "$([math]::Round($app.Size/1MB,1)) MB" }
        $displayName = if ($app.Identity) { "$app.DirName ($app.Identity)" } else { $app.DirName }
        $location = "$($app.RootLabel)\$($app.Parent)\$($app.DirName)"
        $runtimePct = if ($app.TotalMB -gt 0) { [math]::Round($app.RuntimeMB / $app.TotalMB * 100, 0) } else { 0 }

        Write-ScanResult -Category "J" -Name "$displayName (Electron)" -Size $app.Size `
            -Risk "cautious" -Path $app.Path `
            -Advice "Chromium运行时占 ${runtimePct}% ($($app.RuntimeMB)MB/$($app.TotalMB)MB)。如非必须可用网页版替代" `
            -Note "位置: $location | 运行时: $($app.RuntimeMB)MB | 数据: $($app.DataMB)MB | $($app.PakCount)个.pak"
    }
}

Write-Host ""
