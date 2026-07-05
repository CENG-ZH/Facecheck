# FaceCheck 2.0 开发进度记录

> 分支：`testmerge`  
> 基线：README.md 标注的 FaceCheck v1.3  
> 本轮目标：先完成 2.0 的地理围栏最小闭环，并接入失败尝试日志。

## 1. 本轮已完成

### 1.1 地理围栏基础能力

已新增：

- `entry/src/main/ets/models/LocationModel.ets`
- `entry/src/main/ets/kits/LocationAdapter.ets`
- `entry/src/main/ets/services/GeoFenceService.ets`
- `entry/src/main/ets/components/LocationStatusCard.ets`

核心逻辑：

- 发起签到时，可开启位置校验。
- 开启后，使用当前 Pad 位置作为本场签到点。
- 支持地点名称和半径选择。
- 每次刷脸签到前重新获取当前 Pad 位置。
- 使用 Haversine 公式计算当前位置与签到点距离。
- 围栏内继续活体检测和人脸比对。
- 围栏外直接失败，不写入正式成功记录。

### 1.2 权限与系统配置

已修改：

- `entry/src/main/module.json5`
- `entry/src/main/resources/base/element/string.json`

权限策略：

- 仅在开启位置校验或签到前需要校验位置时申请权限。
- 申请 `ohos.permission.APPROXIMATELY_LOCATION` 和 `ohos.permission.LOCATION`。
- 不做后台定位，不做连续轨迹。

### 1.3 数据库 v4 迁移

已修改：

- `entry/src/main/ets/database/DatabaseManager.ets`
- `entry/src/main/ets/database/SessionDao.ets`
- `entry/src/main/ets/database/AttendanceDao.ets`
- `entry/src/main/ets/models/AttendanceModel.ets`

新增字段：

- `attendance_sessions` 保存本场地理围栏配置。
- `attendance_records` 保存成功签到时的位置结果。
- 新增 `check_in_attempts` 表保存失败尝试。

迁移原则：

- 旧数据默认不启用位置校验。
- 旧签到记录默认位置校验通过，避免影响历史统计。
- 新表和索引通过 `CREATE TABLE IF NOT EXISTS`、`CREATE INDEX IF NOT EXISTS` 创建。

### 1.4 签到流程接入

已修改：

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/services/AttendanceService.ets`

新流程：

```text
选择本场成员
-> 地理围栏校验
-> 活体检测
-> 相机/活体图像
-> 人脸质量检测
-> 人脸 1:1 比对
-> 写入正式记录
```

失败处理：

- 位置权限拒绝、定位失败、围栏外失败都会进入失败尝试日志。
- 活体启动失败、活体不通过、拍照取消会进入失败尝试日志。
- 人脸检测或比对失败会进入失败尝试日志。
- 失败尝试不参与出勤率和缺勤统计。
- 修复了部分前置失败后 `isChecking` 没有复位导致按钮卡住的风险。

### 1.5 实时动态与记录页增强

已修改：

- `entry/src/main/ets/pages/Index.ets`
- `entry/src/main/ets/pages/RecordListPage.ets`
- `entry/src/main/ets/services/ExportService.ets`

效果：

- 首页实时动态合并正式签到记录和失败尝试。
- 记录页 SummaryBar 增加“失败尝试”数量。
- 记录页竖屏卡片和横屏表格都能查看失败尝试。
- CSV 导出追加失败尝试行。
- CSV 中“失败原因”列可展示位置、活体、人脸等失败原因。

## 2. 当前验证状态

已完成：

- `git diff --check` 通过。
- 静态扫描未发现明显 ArkTS 字符串截断、接口字段缺失或未引用文件问题。
- 已按项目 `dev-md/harmonyos-knowledge.md` 的 Location Kit 示例核对 `geoLocationManager.getCurrentLocation` 调用。

未完成：

- 当前命令行环境没有 `hvigor` / `ohpm`，无法在终端完成 HAP 构建。
- 需要在 DevEco Studio 中执行 Build / Run，以确认 SDK 真实类型签名和权限弹窗行为。

## 3. DevEco 真机测试清单

### 3.1 普通签到回归

- 关闭地理围栏。
- 发起课程签到。
- 普通刷脸成功。
- 出勤率圆环刷新。
- 记录页出现正式签到记录。
- CSV 能导出。

### 3.2 地理围栏成功路径

- 发起签到时开启地理围栏。
- 点击“使用当前 Pad 位置”。
- 选择半径 100m 或 200m。
- 同地点刷脸签到。
- 位置校验通过后继续活体和人脸比对。
- 成功记录中显示位置距离。

### 3.3 地理围栏失败路径

- 开启地理围栏后，使用较小半径或移动设备到范围外。
- 刷脸前位置校验失败。
- 不写入正式成功记录。
- 首页实时动态显示位置失败原因。
- 记录页“失败尝试”数量增加。
- CSV 追加失败尝试行。

### 3.4 活体与相机异常路径

- 开启活体检测。
- 取消或失败后返回 FaceCheck。
- 页面不应卡死。
- 签到按钮应恢复可点。
- 失败尝试中应出现活体失败原因。

## 4. 下一步建议

1. 在 DevEco Studio 中先做一次 Build，优先修复 ArkTS / es2abc 编译错误。
2. 在 Pad 上跑通普通签到、活体签到、地理围栏签到三个案例并截图。
3. 若 Location Kit 在设备上定位精度较差，默认半径建议保持 100m 或 200m。
4. 下一轮继续做设置页“位置策略”和“设备能力诊断”。
5. 最后更新 README 到 2.0，并补充测试报告、答辩脚本和系统架构说明。
