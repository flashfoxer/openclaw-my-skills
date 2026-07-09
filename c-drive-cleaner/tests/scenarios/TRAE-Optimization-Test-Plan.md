# TRAE IDE Performance Optimization Test Plan

> **测试时间**: 2026-05-19
> **目标**: 验证IDE-001优化方案的有效性
> **预期结果**: C盘空间增加、系统更稳定、开发体验更流畅

---

## 📋 测试清单

### Phase 1: 基准测试（优化前）

- [ ] 记录当前C盘空间
- [ ] 记录当前内存使用情况
- [ ] 记录TRAE启动时间
- [ ] 记录SearchHost.exe CPU使用
- [ ] 截图当前任务管理器状态

### Phase 2: 优化实施

- [ ] Part 1: 配置虚拟内存（E: 32-64GB, C: 4GB）
- [ ] Part 2: 配置Search索引排除
- [ ] Part 3: 优化TRAE设置
- [ ] Part 6: 运行TRAE智能缓存清理

### Phase 3: 优化后验证

- [ ] 记录优化后C盘空间
- [ ] 记录优化后内存使用情况
- [ ] 测试TRAE启动时间
- [ ] 测试SearchHost.exe CPU使用
- [ ] 验证IDE功能正常

---

## 📊 基准数据记录

### 优化前状态

```
日期: ________________
时间: ________________

C盘空间:
├─ 总计: 148.91 GB
├─ 已用: 108.61 GB
└─ 可用: 40.34 GB (27.09%)

内存使用:
├─ 总计: 31.69 GB
├─ 已用: 15.14 GB (47.78%)
└─ 可用: 16.55 GB

TRAE进程:
├─ 进程数: 25
├─ 总内存: _______ MB
└─ 最大实例: _______ MB

SearchHost.exe:
├─ CPU使用: 355 秒
└─ 状态: 索引重建中

任务管理器截图: [ ] 已保存
```

### 优化后状态

```
日期: ________________
时间: ________________

C盘空间:
├─ 总计: 148.91 GB
├─ 已用: _______ GB
└─ 可用: _______ GB (_______%)

内存使用:
├─ 总计: 31.69 GB
├─ 已用: _______ GB (_______%)
└─ 可用: _______ GB

TRAE进程:
├─ 进程数: _______
├─ 总内存: _______ MB
└─ 最大实例: _______ MB

SearchHost.exe:
├─ CPU使用: _______ 秒
└─ 状态: ________________

任务管理器截图: [ ] 已保存
```

---

## ✅ 分步测试执行

### 步骤1: 记录优化前基准

```powershell
# 执行时间: 优化前
Write-Host "=== 优化前基准数据 ===" -ForegroundColor Cyan
Write-Host "C盘空间:" -ForegroundColor Yellow
Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"} | Select-Object DeviceID, @{Name="Free(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}}, @{Name="FreePercent";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100,2)}} | Format-Table -AutoSize
Write-Host "内存使用:" -ForegroundColor Yellow
$os = Get-WmiObject -Class Win32_OperatingSystem
$total = [math]::Round($os.TotalVisibleMemorySize/1MB, 2)
$free = [math]::Round($os.FreePhysicalMemory/1MB, 2)
$used = [math]::Round(($total - $free), 2)
$percent = [math]::Round(($used/$total)*100, 2)
Write-Host "总计: $total GB | 已用: $used GB ($percent%) | 可用: $free GB" -ForegroundColor White
Write-Host "TRAE进程:" -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -like '*Trae*'} | Measure-Object | Select-Object Count | Format-Table
Write-Host "TRAE总内存:" -ForegroundColor Yellow
(Get-Process | Where-Object {$_.ProcessName -like '*Trae*'} | Measure-Object -Property WorkingSet64 -Sum).Sum / 1MB | ForEach-Object { Write-Host "$_ MB" -ForegroundColor White }
```

### 步骤2: Part 1 - 虚拟内存配置

**操作**: 按照Part 1步骤手动配置虚拟内存
**预计时间**: 10分钟
**风险**: 低（需要重启）

```
步骤:
1. Win + R → sysdm.cpl
2. 高级 → 设置 → 高级 → 更改
3. 取消"自动管理"
4. 选择E: → 自定义: 32768 / 65536 → 设置
5. 选择C: → 自定义: 4096 / 4096 → 设置
6. 确定 → 重启
```

**验证**:
```powershell
# 重启后执行
Write-Host "=== 虚拟内存验证 ===" -ForegroundColor Cyan
Get-WmiObject -Class Win32_PageFileUsage | Select-Object AllocatedBaseSize, PeakUsage | Format-Table -AutoSize
Write-Host "C盘pagefile:" -ForegroundColor Yellow
Test-Path "C:\pagefile.sys"
Write-Host "E盘pagefile:" -ForegroundColor Yellow
Test-Path "E:\pagefile.sys"
```

### 步骤3: Part 2 - Search索引排除

**操作**: 配置Windows Search排除开发目录
**预计时间**: 5分钟
**风险**: 低

**验证**:
```powershell
Write-Host "=== Search索引状态 ===" -ForegroundColor Cyan
Get-Process | Where-Object {$_.ProcessName -like '*Search*'} | Select-Object Name, CPU | Format-Table -AutoSize
```

### 步骤4: Part 6 - TRAE智能缓存清理

**操作**: 运行智能缓存清理脚本
**预计时间**: 5分钟
**风险**: 低

```powershell
# TRAE Smart Cache Cleanup
$traePath = "$env:APPDATA\Trae"
$safeToDelete = @('Cache', 'Code Cache', 'CachedData', 'GPUCache', 'DawnGraphiteCache', 'DawnWebGPUCache')

Write-Host "=== TRAE缓存清理 ===" -ForegroundColor Cyan
Write-Host "清理前大小:" -ForegroundColor Yellow
$beforeSize = (Get-ChildItem $traePath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "$beforeSize MB" -ForegroundColor White

Write-Host "清理缓存..." -ForegroundColor Yellow
foreach ($dir in $safeToDelete) {
  $path = Join-Path $traePath $dir
  if (Test-Path $path) {
    $size = (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  已清理: $dir ($size MB)" -ForegroundColor Green
  }
}

Write-Host "清理旧日志..." -ForegroundColor Yellow
$logsPath = Join-Path $traePath "logs"
if (Test-Path $logsPath) {
  $oldLogs = Get-ChildItem $logsPath -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) }
  $count = ($oldLogs | Measure-Object).Count
  $oldLogs | Remove-Item -Force -ErrorAction SilentlyContinue
  Write-Host "  已清理: $count 个旧日志文件" -ForegroundColor Green
}

Write-Host "清理后大小:" -ForegroundColor Yellow
$afterSize = (Get-ChildItem $traePath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "$afterSize MB" -ForegroundColor White
Write-Host "释放空间: $([math]::Round($beforeSize - $afterSize, 2)) MB" -ForegroundColor Green
```

### 步骤5: 优化后验证

```powershell
Write-Host "=== 优化后验证 ===" -ForegroundColor Cyan
Write-Host "C盘空间:" -ForegroundColor Yellow
Get-WmiObject Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "C:"} | Select-Object DeviceID, @{Name="Free(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}}, @{Name="FreePercent";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100,2)}} | Format-Table -AutoSize
Write-Host "内存使用:" -ForegroundColor Yellow
$os = Get-WmiObject -Class Win32_OperatingSystem
$total = [math]::Round($os.TotalVisibleMemorySize/1MB, 2)
$free = [math]::Round($os.FreePhysicalMemory/1MB, 2)
$used = [math]::Round(($total - $free), 2)
$percent = [math]::Round(($used/$total)*100, 2)
Write-Host "总计: $total GB | 已用: $used GB ($percent%) | 可用: $free GB" -ForegroundColor White
Write-Host "TRAE进程:" -ForegroundColor Yellow
Get-Process | Where-Object {$_.ProcessName -like '*Trae*'} | Measure-Object | Select-Object Count | Format-Table
```

---

## 📈 效果评估

### 量化指标对比

| 指标 | 优化前 | 优化后 | 改善 |
|------|--------|--------|------|
| C盘可用空间 | 40.34 GB | ? GB | ? GB ↑ |
| C盘可用百分比 | 27.09% | ?% | ?% ↑ |
| 内存使用率 | 47.78% | ?% | ?% ↓ |
| SearchHost CPU | 355秒 | ?秒 | ?秒 ↓ |
| TRAE总内存 | ? MB | ? MB | ? MB ↓ |

### 主观体验评估

- [ ] TRAE启动速度: 更快 / 无变化 / 更慢
- [ ] 文件搜索速度: 更快 / 无变化 / 更慢
- [ ] AI响应速度: 更快 / 无变化 / 更慢
- [ ] 系统整体响应: 更流畅 / 无变化 / 更卡
- [ ] 多任务切换: 更流畅 / 无变化 / 更卡

---

## ⚠️ 回滚步骤

如果出现问题：

### 虚拟内存回滚
```
Win + R → sysdm.cpl → 高级 → 设置 → 高级 → 更改
勾选"自动管理所有驱动器"
确定 → 重启
```

### TRAE缓存恢复
```powershell
# 关闭TRAE
# 从备份恢复（如果有的话）
# 或者直接重启TRAE会自动重建缓存
```

---

## 📝 测试报告模板

### 优化总结
```
测试日期: ________________
测试人员: ________________

优化项目:
- Part 1: 虚拟内存配置 [ ] 完成 [ ] 跳过 [ ] 回滚
- Part 2: Search索引排除 [ ] 完成 [ ] 跳过 [ ] 回滚
- Part 6: TRAE缓存清理 [ ] 完成 [ ] 跳过 [ ] 回滚

主要成果:
1. C盘空间: 40.34 GB → _______ GB (增加 _______ GB)
2. 内存使用: 47.78% → _______%
3. TRAE进程数: 25 → _______

遇到的问题:
_______________________________________________

总体评价:
[ ] 显著改善
[ ] 部分改善
[ ] 无明显变化
[ ] 出现问题

建议:
_______________________________________________
```

---

## 🎯 下一步建议

基于测试结果：

1. **如果效果显著**: 建议将Part 3-5也实施
2. **如果部分改善**: 建议调整某些设置
3. **如果无明显变化**: 可能需要进一步诊断
4. **如果出现问题**: 使用回滚步骤恢复

---

**测试愉快！** 🚀
