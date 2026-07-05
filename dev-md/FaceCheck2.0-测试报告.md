# FaceCheck 2.0 测试报告

> 测试日期：2026-07-05  
> 分支：`testmerge`  
> 构建目标：`entry@default`  
> SDK：DevEco Studio 本机 SDK，临时设置 `DEVECO_SDK_HOME=F:\DevEco Studio\sdk`

## 1. 本轮代码验证

| 项目 | 结果 | 说明 |
| --- | --- | --- |
| `git diff --check` | 通过 | 未发现补丁空白错误。 |
| Hvigor 版本检查 | 通过 | `hvigorw --version` 输出 `6.22.4`。 |
| HAP 构建 | 通过 | `assembleHap --mode module -p module=entry@default -p product=default --no-daemon` 构建成功。 |

构建命令：

```powershell
$env:DEVECO_SDK_HOME='F:\DevEco Studio\sdk'
& 'F:\DevEco Studio\tools\hvigor\bin\hvigorw.bat' assembleHap --mode module -p module=entry@default -p product=default --no-daemon
```

构建结果：

```text
BUILD SUCCESSFUL
```

说明：构建输出中仍有若干 ArkTS “Function may throw exceptions” 警告，主要来自既有 DAO、导出服务和新增诊断导出的文件写入调用；当前不阻塞构建。后续若要追求更干净的工程输出，可逐步在 DAO 层补充更细粒度的 try/catch 和错误转换。

## 2. 已验证功能点

| 功能 | 状态 | 验证方式 |
| --- | --- | --- |
| 设置服务新增位置策略 | 已构建通过 | `SettingsService` 新增默认位置开关、半径、定位超时，并持久化到 Preferences。 |
| 新建签到读取默认位置策略 | 已构建通过 | `Index.ets` 打开发起签到弹窗时读取设置；定位时使用配置的 timeout。 |
| 设置页位置策略 UI | 已构建通过 | 新增开关、半径 Slider、定位超时 Slider。 |
| 演示数据服务 | 已构建通过 | 新增 `DemoDataService`，可生成/归档 DEMO 班级、课程和学生。 |
| 诊断导出服务 | 已构建通过 | 新增 `DiagnosticService`，通过 DocumentViewPicker 导出无隐私摘要。 |
| 设置页演示/诊断入口 | 已构建通过 | 新增系统诊断卡、演示数据卡。 |

## 3. Pad 真机回归清单

以下项目需要在华为 Pad 上继续截图验证：

1. 设置页调整默认位置策略：开启默认位置校验，半径设为 100m，定位超时设为 10s。
2. 回到签到页，点击发起签到，确认弹窗自动开启地理围栏并带出 100m 半径。
3. 点击“使用当前 Pad 位置”，确认能申请位置权限并记录经纬度与精度。
4. 选择课程成员刷脸签到，确认位置校验通过后继续活体和人脸比对。
5. 人为制造位置失败或权限拒绝，确认首页实时动态和记录页失败尝试有原因。
6. 设置页点击“生成演示数据”，确认教学组织页出现 DEMO 班级、课程和学生。
7. 设置页点击“导出诊断摘要”，确认导出的 txt 不包含姓名、学号、人脸路径或签到明细。
8. 记录页导出 CSV，确认位置校验、距离、失败原因和失败尝试行可见。

## 4. 已知边界

- 当前仍是教师 Pad 设备模式，不是学生自带设备模式；位置校验验证的是签到设备是否仍在课堂地点范围内。
- 当前人脸签到仍采用“选择学生后 1:1 比对”，不做全班 1:N 自动识别。
- 演示数据不会生成可用于真实比对的人脸照片；需要演示完整刷脸时，仍需给至少一名测试学生手动录入人脸。
- 位置精度受室内环境影响较大，课堂演示建议默认半径使用 100m 或 200m。
