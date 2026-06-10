# FaceCheck：一起刷脸签到

<p align="center">
  <strong>📸 HarmonyOS 原生课堂刷脸签到应用</strong><br>
  基于 ArkTS + ArkUI + Core Vision Kit + ArkData 构建
</p>

<p align="center">
  <img src="https://img.shields.io/badge/HarmonyOS-6.1-1677FF?style=flat-square">
  <img src="https://img.shields.io/badge/API-23-1677FF?style=flat-square">
  <img src="https://img.shields.io/badge/Version-1.3-success?style=flat-square">
  <img src="https://img.shields.io/badge/UI-PlanUI_100%25-brightgreen?style=flat-square">
</p>

---

## ✨ v1.3 新特性

### 缺勤记录系统
结束场次时自动为未签到成员生成缺勤记录，考勤记录页统一展示 **正常 / 迟到 / 缺勤 / 失败** 四种状态。缺勤记录显示「未签到 + —」标识，红色状态胶囊区分清晰。

### PlanUI 设计系统 100% 完成
全面重构 UI 视觉层级，建立统一设计令牌系统，零硬编码色值残留：

- **5 个可复用组件**：`FaceEnrollButton` 按压动画、`StatusPill` 状态胶囊、`CircleProgress` 圆环进度条、`AnimatedCard` 交错入场、`AppBottomNav` 激活动画
- **响应式布局**：三档适配 — 手机竖屏 (compact)、平板横屏 (expanded)、常规 (normal)
- **细腻动效**：按钮按压缩放、列表交错入场、分数滚动动画、Slider 吸附弹跳、结果卡片淡入

### 技术改进
- 消除 ~14 个冗余 `@State` 变量和 ~100 行重复代码
- ArkTS 兼容性修复：`@BuilderParam` 链式修饰符、命名冲突等
- 数据库 v3 关系模型迁移

> 完整交付报告详见 [PlanUI 完成情况报告](dev-md/PlanUI-完成情况报告.md)

---

## 📱 主要功能

| 功能 | 说明 |
|------|------|
| 👥 **人员管理** | 学生信息增删改查，支持班级归属 |
| 🏫 **教学组织** | 班级、课程、选课关系管理 |
| 📸 **人脸录入** | 前置摄像头拍照，单人正面检测与质量评估 |
| ✅ **刷脸签到** | 1:1 人脸比对签到，含重复签到拦截 |
| 🧪 **活体检测** | 可选交互式活体检测，防止照片欺骗 |
| 📊 **签到统计** | 应到 / 已到 / 迟到 / 缺勤 + 出勤率圆环 |
| 🔄 **实时动态** | 签到活动实时滚动展示，状态颜色区分 |
| 📋 **考勤记录** | 按场次/班级/日期筛选、搜索，支持 CSV 导出 |
| ⚙️ **系统设置** | 人脸阈值、迟到判定、活体开关、数据清除 |

---

## 🏗 项目架构

```
entry/src/main/ets/
├── components/         可复用 UI 组件
│   ├── FaceEnrollButton   按钮按压缩放动画
│   ├── AnimatedCard       卡片交错入场动画
│   ├── CircleProgress     圆环进度条
│   ├── StatusPill         状态胶囊标签
│   └── AppBottomNav       底部导航栏
├── pages/              页面
│   ├── Index.ets             首页（签到）
│   ├── RecordListPage.ets    考勤记录
│   ├── UserListPage.ets      人员管理
│   ├── OrganizationPage.ets  教学组织
│   ├── SettingsPage.ets      设置
│   └── FaceEnrollPage.ets    人脸录入
├── services/           业务服务层
│   ├── AttendanceService     签到服务
│   ├── UserService           人员服务
│   ├── OrganizationService   组织服务
│   ├── SettingsService       设置服务
│   ├── ExportService         CSV 导出
│   └── PrivacyService        隐私清除
├── database/           数据访问层
│   ├── DatabaseManager       数据库单例
│   ├── AttendanceDao         签到 DAO
│   ├── SessionDao            场次 DAO
│   ├── UserDao               用户 DAO
│   ├── SessionMemberDao      成员 DAO
│   └── OrganizationDao       组织 DAO
├── models/             数据模型
├── kits/               硬件抽象层
│   ├── CameraAdapter         相机适配
│   ├── FaceVisionAdapter     人脸检测/比对
│   └── LivenessAdapter       活体检测
└── utils/              工具与设计系统
    ├── DesignTokens          全局设计令牌
    ├── AttendanceRules       签到规则
    ├── DateUtils             日期工具
    └── Logger                日志
```

---

## 🛠 技术栈

| 技术 | 用途 |
|------|------|
| ArkTS + ArkUI | 声明式 UI 开发 |
| DevEco Studio + HarmonyOS SDK 6.x | 开发工具链 |
| Core Vision Kit | 人脸检测 / 人脸比对 |
| Vision Kit | 交互式活体检测 |
| ArkData RelationalStore | 关系型数据库 |
| ArkData Preferences | 轻量配置存储 |
| Camera Kit / Image Kit | 相机拍照与图像处理 |
| 媒体查询 (MediaQuery) | 响应式布局适配 |

---

## 🚀 运行方式

1. 使用 **DevEco Studio** 打开项目根目录
2. 等待工程同步完成，在 `Project Structure` 中配置本机调试签名
3. 连接已开启开发者模式 + USB 调试的 HarmonyOS 设备（华为手机 / Pad）
4. 选择 `entry` 模块及 `default` 产品后运行
5. 首次使用时授予**相机权限**

> 仓库中的 `build-profile.json5` 不含签名信息。签名证书、构建产物、设备截图和本地数据库均已加入 `.gitignore`，请勿提交个人签名材料或真实人脸数据。

---

## 📖 项目文档

| 文档 | 说明 |
|------|------|
| [PlanUI 完成情况报告](dev-md/PlanUI-完成情况报告.md) | **v1.3** UI 优化交付物清单 |
| [项目完整说明](dev-md/FaceCheck-项目完整说明.md) | 功能规格与架构总览 |
| [文件结构与流程详解](dev-md/FaceCheck-项目文件结构与依赖流程详解.md) | 依赖关系与业务流程 |
| [v1.1 优化交付说明](dev-md/FaceCheck-v1.1-优化交付说明.md) | 历史版本优化记录 |
| [开发计划](dev-md/dev%20plan.md) | 迭代路线图 |
| [人脸功能实现说明](dev-md/核心部分人脸功能的实现说明.md) | 人脸检测/比对技术细节 |
| [ArkTS 开发规范](dev-md/HarmonyOS_ArkTS开发规范与最佳实践.md) | 编码规范参考 |

---

## ⚠️ 已知边界

- 当前为**选择学生后 1:1 人脸验证**，非全班 1:N 自动识别
- 活体检测依赖**真实 HarmonyOS 设备**及 Vision Kit 支持
- 面向**教学实践与小规模课堂考勤**，不应用于高安全级身份认证
- 缺勤记录在**场次结束时自动生成**，仅记录应到而未签到的人员

---

## 🔒 隐私声明

人脸属于敏感个人信息。录入前应获得本人授权，并在测试结束后及时清理人脸照片和考勤数据。应用的人脸照片和业务数据默认保存在 **设备应用沙箱** 中，可通过「设置 → 清除全部人脸与考勤数据」一键清除。
