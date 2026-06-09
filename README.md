# FaceCheck：一起刷脸签到

FaceCheck 是一款基于 HarmonyOS 的课堂刷脸签到应用，使用 ArkTS、ArkUI、ArkData、Core Vision Kit 和 Vision Kit 开发，可在华为手机及 Pad 上运行。

## 主要功能

- 班级、课程、学生及选课关系管理
- 人脸拍摄、检测、录入和重新录入
- 基于 1:1 人脸比对的课堂签到
- 可选的交互式活体检测
- 场次应到名单快照和重复签到拦截
- 应到、已到、迟到、未到及出勤率统计
- 实时签到动态、历史记录和数据导出
- 手机、Pad 横屏及竖屏响应式布局

## 技术栈

- ArkTS + ArkUI
- DevEco Studio + HarmonyOS SDK 6.x
- Core Vision Kit Face Detector / Face Comparator
- Vision Kit Interactive Liveness
- ArkData RelationalStore / Preferences
- Camera Kit / Image Kit

## 运行方式

1. 使用 DevEco Studio 打开项目。
2. 等待 DevEco Studio 完成工程同步，并在 Project Structure 中配置本机调试签名。
3. 连接已开启开发者模式和 USB 调试的 HarmonyOS 设备。
4. 选择 `entry` 模块及 `default` 产品后运行。
5. 首次使用时授予相机权限。

> 仓库中的 `build-profile.json5` 不含签名信息。签名证书、构建产物、设备截图和本地数据库均已加入 `.gitignore`，请勿提交个人签名材料或真实人脸数据。

## 项目文档

- [项目完整说明](dev-md/FaceCheck-项目完整说明.md)
- [项目文件结构、依赖关系与业务流程详解](dev-md/FaceCheck-项目文件结构与依赖流程详解.md)
- [v1.1 优化交付说明](dev-md/FaceCheck-v1.1-优化交付说明.md)
- [开发计划](dev-md/dev%20plan.md)
- [HarmonyOS ArkTS 开发规范与最佳实践](dev-md/HarmonyOS_ArkTS开发规范与最佳实践.md)

## 已知边界

- 当前为选择学生后的 1:1 人脸验证，不是全班 1:N 自动识别。
- 活体检测依赖真实设备、HarmonyOS 版本和 Vision Kit 支持情况。
- 本项目面向教学实践和小规模课堂考勤，不应直接作为高安全级身份认证系统。

## 隐私

人脸属于敏感个人信息。录入前应获得本人授权，并在测试结束后及时清理人脸照片和考勤数据。应用的人脸照片和业务数据默认保存在设备应用沙箱中。
