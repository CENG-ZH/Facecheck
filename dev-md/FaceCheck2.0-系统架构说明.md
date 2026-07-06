# FaceCheck 2.0 系统架构说明

> 基线分支：`testmerge`  
> 当前目标：在 v1.3 的人脸签到闭环上，形成“课程名单快照 + 地理围栏 + 活体检测 + 人脸比对 + 失败可解释 + 报表导出”的 2.0 可交付版本。

## 1. 分层结构

FaceCheck 2.0 继续采用本地端侧架构，不引入后端服务，所有业务数据保存在应用沙箱内。

```text
ArkUI Pages
  -> Components
  -> Services
  -> DAO
  -> ArkData RelationalStore / Preferences

Kits
  -> Camera Kit / Image Kit
  -> Core Vision Kit
  -> Vision Kit Interactive Liveness
  -> Location Kit
```

## 2. 页面层

| 文件 | 职责 |
| --- | --- |
| `entry/src/main/ets/pages/Index.ets` | 签到首页；负责发起场次、选择学生、地理围栏预校验、活体/拍照/人脸比对入口、实时动态和本场统计。 |
| `entry/src/main/ets/pages/UserListPage.ets` | 人员管理；维护学生、班级归属、人脸录入状态。 |
| `entry/src/main/ets/pages/OrganizationPage.ets` | 教学组织；维护行政班级、课程、选课关系。 |
| `entry/src/main/ets/pages/RecordListPage.ets` | 考勤记录；展示正式记录、缺勤记录、失败尝试、筛选和 CSV 导出。 |
| `entry/src/main/ets/pages/SettingsPage.ets` | 系统设置；维护识别阈值、迟到规则、活体开关、地理围栏默认策略、诊断导出、演示数据和隐私清理。 |
| `entry/src/main/ets/pages/FaceEnrollPage.ets` | 人脸录入；采集注册照并做基础人脸质量校验。 |

## 3. 业务服务层

| 文件 | 职责 |
| --- | --- |
| `AttendanceService.ets` | 签到主业务；创建/结束场次、生成名单快照、写入记录、生成缺勤、记录失败尝试。 |
| `UserService.ets` | 学生档案、人脸路径和人员统计。 |
| `OrganizationService.ets` | 班级、课程、选课关系。 |
| `SettingsService.ets` | Preferences 设置；2.0 新增默认位置开关、默认围栏半径、定位超时。 |
| `GeoFenceService.ets` | 本地 Haversine 距离计算和围栏判定。 |
| `ExportService.ets` | 考勤 CSV 导出；包含位置校验、失败原因和失败尝试行。 |
| `DemoDataService.ets` | 生成/归档 DEMO 班级、课程和学生，不生成真实人脸照片。 |
| `DiagnosticService.ets` | 导出无隐私诊断摘要，便于真机测试和答辩排查。 |
| `PrivacyService.ets` | 清理人脸照片、签到场次和考勤记录。 |

## 4. 数据访问层

| 文件 | 职责 |
| --- | --- |
| `DatabaseManager.ets` | RDB 初始化和 v4 迁移。 |
| `AttendanceDao.ets` | 正式签到记录读写和统计。 |
| `SessionDao.ets` | 签到场次读写，保存地理围栏配置。 |
| `SessionMemberDao.ets` | 场次名单快照，保证课程名单在场次创建后不被后续人员调整影响。 |
| `CheckInAttemptDao.ets` | 失败尝试日志，记录位置、活体、人脸等失败原因。 |
| `UserDao.ets` | 学生基础信息和人脸录入状态。 |
| `OrganizationDao.ets` | 班级、课程、选课关系。 |

## 5. 关键流程

### 5.1 发起签到

```text
老师选择课程
-> SettingsService 读取默认位置策略
-> 可选：LocationAdapter 获取当前 Pad 位置
-> SessionDao 写入场次
-> SessionMemberDao 冻结本场应到名单
```

地理围栏采用“教师 Pad 设备模式”：发起时记录 Pad 当前位置作为本场签到点；每次学生刷脸前再次获取 Pad 当前定位，确认设备仍在签到地点半径内。

### 5.2 刷脸签到

```text
选择学生
-> 校验当前场次和名单快照
-> 若本场启用位置校验，先做 Location Kit + GeoFenceService 判定
-> 若启用活体，调用交互式活体检测
-> 采集现场图像
-> Core Vision Kit 人脸检测与质量校验
-> 1:1 人脸比对
-> AttendanceDao 写入正式记录
-> 首页实时动态刷新
```

失败时不写入正式成功记录，而是进入 `check_in_attempts`，用于记录页、CSV 和问题解释。

### 5.3 结束场次

```text
获取本场名单快照
-> 查询已有正式记录
-> 为完全未签到成员生成缺勤记录
-> 更新场次状态
-> 记录页可统一展示正常、迟到、缺勤、失败尝试
```

## 6. 2.0 新增交付能力

- 地理围栏闭环：发起场次定位、签到前定位、距离判定、失败尝试记录、导出字段。
- 设置页位置策略：默认开关、默认半径、定位超时会真实影响新建场次和定位请求。
- 演示数据：一键生成 DEMO 班级、课程和学生，便于无真实数据时演示组织关系和课程名单。
- 系统诊断：导出版本、能力、设置和统计摘要，不导出姓名、学号、人脸照片或签到明细。
- README/测试报告/演示脚本：支撑期末提交和答辩。

## 7. 隐私边界

- 人脸照片、签到记录和位置记录只保存在应用沙箱。
- 诊断摘要只包含统计与配置，不导出个人明细。
- 演示数据使用 `DEMO-` 课程编号和 `D2026` 学号前缀，便于识别和清理。
- 设置页“清除全部人脸与考勤数据”会保留组织和人员基本信息，但清理敏感签到闭环数据。
