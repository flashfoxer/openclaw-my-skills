# 回滚指南 — 误操作后的恢复步骤

## 如果你误删了临时文件

```
临时文件删除后不可恢复，但也不影响系统运行。
系统会按需重新生成。
```

## 如果你误清了回收站

```
使用专业的文件恢复工具（如 Recuva）。
不要在 C 盘写入任何新文件，这会覆盖已删除的数据！
```

## 如果你误关了休眠(`powercfg -h off`)

```
powercfg.exe /hibernate on
# 重新开启休眠，hiberfil.sys 会重建
```

## 如果你误清了系统还原点

```
系统还原点删除后无法恢复。
建议定期手动创建还原点:
  Win+R → sysdm.cpl → 系统保护 → 创建
```

## 如果你迁移开发缓存后程序报错

```
1. 检查环境变量是否设置正确:
   [System.Environment]::GetEnvironmentVariable("变量名", "User")

2. 删除错误的环境变量:
   [System.Environment]::SetEnvironmentVariable("变量名", $null, "User")

3. 恢复默认行为（删除环境变量后程序自动使用默认C盘路径）

4. 确保目标路径存在且可写
```

## 如果 mklink /J 符号链接失败

```
1. 确保原目录已被删除或重命名:
   dir <路径>  # 确认不存在

2. 确保目标路径存在:
   dir D:\target\path

3. 以管理员身份运行 cmd:
   mklink /J "C:\原路径" "D:\目标路径"

4. 如有备份(源目录_BACKUP_日期)，可恢复:
   Remove-Item "C:\原路径" -Force
   Rename-Item "C:\原路径_BACKUP_日期" "C:\原路径"
```

## 如果 setx 环境变量导致系统问题

```
1. 查看当前用户变量:
   [System.Environment]::GetEnvironmentVariables("User")

2. 删除问题变量:
   [System.Environment]::SetEnvironmentVariable("变量名", $null, "User")

3. 重启命令行窗口

4. 重启 Windows 后生效
```

## 如果 C 盘空间异常减少

```
1. 运行 safety/snapshot-before-after.ps1 -Mode after 查看对比
2. 检查是否有程序在后台大量写入
3. 检查 Windows 更新是否正在进行
4. 检查 Delivery Optimization 是否占满

C盘正常波动 1-5 GB 是正常的。
```

## 紧急恢复 — 使用系统还原

```
Win+R → rstrui.exe
选择一个恢复点 → 下一步
```

---

> 所有操作前都会自动生成快照日志在 C:\cleanup_snapshots\ 和 C:\cleanup_log_*
> 回滚前可以先去这些日志中确认操作内容。
