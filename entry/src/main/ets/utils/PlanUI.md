# FaceCheck UI & 动画优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 FaceCheck 从"功能实现"升级为"精致质感"，覆盖首页、签到结果、人员列表、记录列表、设置页的视觉层级重建与动效系统建设。

**Architecture:** 两条并行线：(1) 设计系统层——在 `utils/DesignTokens.ets` 抽取全局颜色/字体/间距/阴影常量，各页面引用；(2) 组件增强层——为通用 UI 组件（按钮、状态标签、圆环进度条、卡片）封装 `@Builder` 可复用组件，消除样式散落在各页面中的技术债。

**Tech Stack:** ArkTS + ArkUI (animateTo / transition / @State 驱动) + 自定义 `@Builder` 组件库

---

## 文件结构总览

```
entry/src/main/ets/
├── utils/
│   ├── DesignTokens.ets          # 新建：全局设计令牌（颜色/字体/间距/阴影）
│   └── DateUtils.ets             # 已有，无需修改
├── components/
│   ├── AppBottomNav.ets          # 修改：底部导航动效
│   ├── StatusPill.ets            # 新建：状态胶囊标签组件
│   ├── CircleProgress.ets        # 新建：圆环进度条组件（出勤率/比对分数）
│   ├── AnimatedCard.ets          # 新建：带入场动画的卡片包装器
│   └── FaceEnrollButton.ets     # 新建：带按压反馈的主按钮
├── pages/
│   ├── Index.ets                 # 修改：首页视觉重构 + 签到结果动效
│   ├── RecordListPage.ets        # 修改：状态标签化 + 列表交错入场
│   ├── UserListPage.ets          # 修改：人员卡片阴影 + 列表交错入场
│   ├── OrganizationPage.ets      # 修改：同上
│   ├── SettingsPage.ets          # 修改：Slider 吸附弹跳动效
│   └── FaceEnrollPage.ets        # 修改：摄像头预览卡片化 + 录入成功动效
└── services/
    └── AttendanceService.ets     # 无需修改
```

---

## 设计系统令牌（DesignTokens）

在改动任何页面之前，必须先建立 `DesignTokens.ets`，确保所有页面引用同一套设计常量。

### 颜色系统（三层）

| Token 名 | 值 | 用途 |
|---|---|---|
| `colorBg` | `#F5F7F9` | 全局页面背景（微暖灰白） |
| `colorCard` | `#FFFFFF` | 卡片/面板背景 |
| `colorPrimary` | `#1677FF` | 主品牌蓝（HMS 标准蓝） |
| `colorSuccess` | `#00B42A` | 成功状态（鲜绿） |
| `colorWarning` | `#FF7D00` | 迟到/警告状态（橙） |
| `colorDanger` | `#F53F3F` | 失败/缺勤状态（红） |
| `colorTextPrimary` | `#1D2129` | 主文字（近黑） |
| `colorTextSecondary` | `#4E5969` | 次要文字 |
| `colorTextTertiary` | `#86909C` | 辅助/占位文字 |
| `colorBorder` | `#E5E6EB` | 分割线/边框 |
| `colorInputBg` | `#F1F3F5` | 输入框背景 |

### 阴影系统

| Token 名 | 值 | 用途 |
|---|---|---|
| `shadowCard` | `shadow({ radius: 15, color: '#1A000000', offsetY: 6 })` | 卡片浮起 |
| `shadowButton` | `shadow({ radius: 8, color: '#20007DFF', offsetY: 3 })` | 按钮按压前 |
| `shadowButtonPressed` | `shadow({ radius: 20, color: '#30007DFF', offsetY: 6 })` | 按钮按压时 |

### 间距/圆角系统

| Token 名 | 值 | 用途 |
|---|---|---|
| `radiusCard` | `12` | 卡片圆角 |
| `radiusButton` | `6` | 按钮圆角 |
| `radiusPill` | `100` | 状态标签胶囊 |
| `spacingBase` | `4` | 基础间距单位 |
| `spacingCard` | `16` | 卡片内边距 |
| `spacingSection` | `12` | 区块间距 |

---

## 改动决策说明

| 用户想法 | 最终决策 | 理由 |
|---|---|---|
| 毛玻璃出勤率圆环 | ❌ 改为半透明叠加圆环 | `backdropBlur` 在部分 HarmonyOS 设备上有性能问题，改用 `rgba` 半透明背景替代 |
| 按钮呼吸效果 | ❌ 取消 | 无限循环动画会干扰用户注意力，属于过度设计 |
| 按钮涟漪扩散 | ⚠️ 改为 scale+shadow 组合 | Material 风格涟漪与 HarmonyOS 视觉语言不搭，scale+shadow 效果更好且零成本 |
| Slider 物理弹簧回弹 | ⚠️ 降级为"吸附弹跳" | 完整弹簧曲线需自定义 Gesture 实现复杂，改用数值吸附 + translateY 微弹跳，收益/成本比更高 |
| 列表交错入场 | ✅ 全量执行 | 所有 List 列表均加入 stagger 入场动画 |
| 状态标签化 | ✅ 全量执行 | 正常/迟到/失败三档状态均改为 Pill 标签 |
| 圆环进度条（出勤率/分数） | ✅ 全量执行 | 新建 `CircleProgress` 组件替换纯数字显示 |
| 数字从 0 滚动到目标值 | ✅ 执行（分数场景） | 比对成功时的相似度数字滚动动画 |
| 背景/卡片/shadow 层级 | ✅ 全量执行 | 所有卡片加入 shadow，设计令牌统一管理 |

---

## Task 1: 建立设计系统令牌

**Files:**
- Create: `FaceCheck_Merge/Facecheck/entry/src/main/ets/utils/DesignTokens.ets`

- [ ] **Step 1: 创建 DesignTokens.ets**

```typescript
/**
 * DesignTokens.ets — FaceCheck 全局设计令牌
 * 所有颜色/阴影/圆角/间距常量集中管理，确保多页面一致性。
 * 使用方法：在 .ets 文件中 import { Colors, Shadows, Radius, Spacing } from '../utils/DesignTokens'
 * 然后引用 Colors.bg、Shadows.card 等，避免散落硬编码色值。
 */
export class Colors {
  // 背景
  static readonly bg: string = '#F5F7F9';          // 页面背景（微暖灰白）
  static readonly card: string = '#FFFFFF';           // 卡片背景（纯白）
  static readonly inputBg: string = '#F1F3F5';        // 输入框背景

  // 品牌 & 状态
  static readonly primary: string = '#1677FF';        // 主蓝（HMS 标准蓝）
  static readonly success: string = '#00B42A';        // 成功（鲜绿）
  static readonly warning: string = '#FF7D00';         // 迟到/警告（橙）
  static readonly danger: string = '#F53F3F';          // 失败/危险（红）

  // 文字
  static readonly textPrimary: string = '#1D2129';     // 主文字（近黑）
  static readonly textSecondary: string = '#4E5969';   // 次要文字
  static readonly textTertiary: string = '#86909C';   // 辅助/占位文字

  // 边框/分割
  static readonly border: string = '#E5E6EB';
  static readonly borderLight: string = '#F2F3F5';

  // 状态背景（浅色）
  static readonly successBg: string = '#E6FFF2';      // 成功状态浅背景
  static readonly warningBg: string = '#FFF7E6';      // 迟到状态浅背景
  static readonly dangerBg: string = '#FFF1F0';       // 失败状态浅背景
}

export class Shadows {
  static readonly card: ShadowOptions = {
    radius: 15,
    color: '#1A000000',
    offsetY: 6
  };
  static readonly button: ShadowOptions = {
    radius: 8,
    color: '#20007DFF',
    offsetY: 3
  };
  static readonly buttonPressed: ShadowOptions = {
    radius: 20,
    color: '#30007DFF',
    offsetY: 6
  };
}

export class Radius {
  static readonly card: number = 12;
  static readonly button: number = 6;
  static readonly pill: number = 100;
  static readonly input: number = 6;
}

export class Spacing {
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly base: number = 12;
  static readonly card: number = 16;
  static readonly lg: number = 20;
}
```

- [ ] **Step 2: Commit**

```bash
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/utils/DesignTokens.ets
git commit -m "feat(ui): add DesignTokens global design system"
```

---

## Task 2: 构建状态胶囊标签组件 StatusPill

**Files:**
- Create: `FaceCheck_Merge/Facecheck/entry/src/main/ets/components/StatusPill.ets`
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/RecordListPage.ets`（替换纯文字状态）
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets`（替换实时动态中的状态文字）

- [ ] **Step 1: 创建 StatusPill.ets**

```typescript
/**
 * StatusPill.ets — 状态胶囊标签
 * 将签到状态（正常/迟到/失败）显示为彩色胶囊标签，
 * 替代原来的纯文字，颜色从 DesignTokens 读取。
 */
import { Colors } from '../utils/DesignTokens';

export enum StatusType {
  NORMAL = 'normal',
  LATE = 'late',
  FAILED = 'failed'
}

@Component
export struct StatusPill {
  @Prop status: StatusType = StatusType.NORMAL;
  @Prop text: string = '';

  private getBgColor(): string {
    if (this.status === StatusType.NORMAL) return Colors.successBg;
    if (this.status === StatusType.LATE) return Colors.warningBg;
    return Colors.dangerBg;
  }

  private getTextColor(): string {
    if (this.status === StatusType.NORMAL) return Colors.success;
    if (this.status === StatusType.LATE) return Colors.warning;
    return Colors.danger;
  }

  build() {
    Text(this.text)
      .fontSize(11)
      .fontColor(this.getTextColor())
      .fontWeight(FontWeight.Medium)
      .padding({
        left: 8,
        right: 8,
        top: 3,
        bottom: 3
      })
      .backgroundColor(this.getBgColor())
      .borderRadius(100)
  }
}
```

- [ ] **Step 2: 修改 RecordListPage.ets — 将状态文字替换为 StatusPill**

读取 `RecordListPage.ets` 完整代码，找到以下两处状态文字渲染逻辑（大约在 recordList 的 ForEach 渲染处），用 StatusPill 替换：

将：
```typescript
Text(this.getStatusText(record.status))
  .fontSize(12)
  .fontColor(record.status === CheckInStatus.NORMAL ? '#34C759' :
             record.status === CheckInStatus.LATE ? '#F59E0B' : '#FF3B30')
```

替换为（import StatusPill 和 getStatusText 辅助方法复用 Index.ets 中的逻辑）：
```typescript
StatusPill({
  status: record.status === CheckInStatus.NORMAL ? StatusType.NORMAL :
          record.status === CheckInStatus.LATE ? StatusType.LATE : StatusType.FAILED,
  text: record.status === CheckInStatus.NORMAL ? '正常' :
        record.status === CheckInStatus.LATE ? '迟到' : '失败'
})
```

- [ ] **Step 3: 修改 Index.ets — 实时动态面板中的状态文字替换为 StatusPill**

在 Index.ets 的 `recentPanel()` @Builder 中找到：
```typescript
Text(activity.statusText)
  .fontSize(dense ? 10 : 11)
  .fontColor(activity.success ? '#34C759' : '#FF3B30')
```
替换为：
```typescript
StatusPill({
  status: activity.success ? StatusType.NORMAL : StatusType.FAILED,
  text: activity.statusText
})
```

在 Index.ets 的 `resultPanel()` @Builder 中找到状态文字，替换为 StatusPill。

- [ ] **Step 4: Commit**

```bash
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/components/StatusPill.ets
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/RecordListPage.ets
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets
git commit -m "feat(ui): add StatusPill component, replace plain status text in RecordListPage and Index"
```

---

## Task 3: 构建圆环进度条组件 CircleProgress

**Files:**
- Create: `FaceCheck_Merge/Facecheck/entry/src/main/ets/components/CircleProgress.ets`
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets`（出勤率展示替换）

- [ ] **Step 1: 创建 CircleProgress.ets（出勤率场景：静态/无动画版）**

```typescript
/**
 * CircleProgress.ets — 圆环进度条组件
 * 用于出勤率展示（首页 statsPanel）和比对分数展示（签到结果）
 *
 * 用法示例（出勤率）:
 *   CircleProgress({
 *     value: 0.87,       // 0.0 ~ 1.0
 *     size: 100,
 *     strokeWidth: 10,
 *     color: Colors.primary,
 *     label: '出勤率'
 *   })
 */
import { Colors } from '../utils/DesignTokens';

@Component
export struct CircleProgress {
  @Prop value: number = 0;        // 0.0 ~ 1.0
  @Prop size: number = 80;        // 圆环直径 vp
  @Prop strokeWidth: number = 8;  // 圆环线宽 vp
  @Prop color: string = Colors.primary;   // 进度颜色
  @Prop label: string = '';       // 底部标签文字（可选）
  @Prop showPercent: boolean = true;      // 是否显示百分比数字

  build() {
    Column() {
      Stack() {
        // 背景圆环（用 Shape 绘制）
        Circle({ width: this.size, height: this.size })
          .fill(Color.Transparent)
          .stroke(Colors.border)
          .strokeWidth(this.strokeWidth)

        // 进度圆弧（用 Arc 近似，strokeWidth 与背景圆一致）
        Circle({ width: this.size, height: this.size })
          .fill(Color.Transparent)
          .stroke(this.color)
          .strokeWidth(this.strokeWidth)
          .strokeDashArray([this.value * Math.PI * this.size, 1000])
          .strokeLineCap(StrokeLineCap.Round)
          .rotate({ angle: -90 }) // 从 12 点钟方向开始

        // 中心数字
        if (this.showPercent) {
          Text(`${Math.round(this.value * 100)}%`)
            .fontSize(Math.round(this.size * 0.22))
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.textPrimary)
        }
      }
      .width(this.size)
      .height(this.size)

      if (this.label !== '') {
        Text(this.label)
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 8 })
      }
    }
  }
}
```

> **注意：** ArkUI 的 `Circle` + `strokeDashArray` 组合在 API 12 上绘制进度弧是标准做法。若弧形绘制效果不理想，备选方案是用两个半圆 `Arc` 组件拼合，或用 `Canvas` 绑定自定义路径。

- [ ] **Step 2: 修改 Index.ets 的 statsPanel() — 出勤率替换为 CircleProgress**

在 `statsPanel()` @Builder 中找到 Divider 后的大数字区域：
```typescript
Divider().color('#E5E5E5').margin({ top: 6, bottom: 12 })
Text(this.stats.totalUsers > 0
  ? `${Math.round(this.stats.checkedIn / this.stats.totalUsers * 100)}%`
  : '0%')
  .fontSize(30)
  .fontWeight(FontWeight.Bold)
  .fontColor('#007DFF')
Text('出勤率')
  .fontSize(12)
  .fontColor('#989A9C')
  .margin({ top: 3 })
```

替换为（引入 CircleProgress，value 计算出勤率）：
```typescript
CircleProgress({
  value: this.stats.totalUsers > 0
    ? this.stats.checkedIn / this.stats.totalUsers
    : 0,
  size: 90,
  strokeWidth: 9,
  color: Colors.primary,
  label: '出勤率'
})
.width('100%')
.margin({ top: 8 })
```

- [ ] **Step 3: Commit**

```bash
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/components/CircleProgress.ets
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets
git commit -m "feat(ui): add CircleProgress component, replace attendance rate in statsPanel"
```

---

## Task 4: 卡片阴影层级改造（全页面统一）

**Files:**
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets`
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/RecordListPage.ets`
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/UserListPage.ets`
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/OrganizationPage.ets`

- [ ] **Step 1: 修改 Index.ets — 全局背景色 + 所有卡片阴影**

在 `Index.ets` build() 方法中：
1. 全局 Column 背景色 `#F1F3F5` → `Colors.bg`（`#F5F7F9`）
2. 找到所有 `.backgroundColor('#FFFFFF')` 的 @Builder 组件，在其后追加 `.shadow(Shadows.card).borderRadius(Radius.card)`
   - `sessionSummary()` 的白色背景 Column
   - `statsStrip()` / `statsPanel()` 的白色背景 Column
   - `peoplePanel()` 的白色背景 Column
   - `recentPanel()` 的白色背景 Column
   - `createSessionDialog()` 的 Column

- [ ] **Step 2: 修改 RecordListPage.ets — 记录卡片阴影**

读取 RecordListPage.ets，找到白色背景的 Column 容器，在 `.backgroundColor('#FFFFFF')` 后追加 `.shadow(Shadows.card).borderRadius(Radius.card)`。

- [ ] **Step 3: 修改 UserListPage.ets — 人员列表卡片阴影**

读取 UserListPage.ets，找到白色背景 Column 容器，同上追加阴影和圆角。

- [ ] **Step 4: 修改 OrganizationPage.ets — 组织页面卡片阴影**

读取 OrganizationPage.ets，同上。

- [ ] **Step 5: Commit**

```bash
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/RecordListPage.ets
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/UserListPage.ets
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/OrganizationPage.ets
git commit -m "feat(ui): add card shadow and borderRadius across all pages, unify background to DesignTokens"
```

---

## Task 5: 按钮按压反馈动效（带 scale + shadow）

**Files:**
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets`
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/components/AppBottomNav.ets`

- [ ] **Step 1: 修改 Index.ets — 主签到按钮添加按压动画**

在 Index.ets 中找到 `checkInButton()` @Builder，在 Button 上添加 Touch 事件：

```typescript
@Builder
private checkInButton() {
  Button() {
    Row() {
      Image($r('app.media.icon_camera'))
        .width(19)
        .height(19)
        .fillColor('#FFFFFF')
      Text(this.isChecking ? (this.stepText || '处理中') :
        (this.selectedUserName ? `为 ${this.selectedUserName} 签到` : '选择人员后刷脸签到'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .margin({ left: 7 })
        .maxLines(1)
    }
  }
  .width('100%')
  .height(48)
  .type(ButtonType.Normal)
  .backgroundColor(this.selectedUserId >= 0 && !this.isChecking ? Colors.primary : '#B8C1CC')
  .borderRadius(Radius.button)
  .shadow(this.selectedUserId >= 0 && !this.isChecking ? Shadows.button : { radius: 0, color: 'transparent', offsetY: 0 })
  .margin({ top: 10 })
  .enabled(this.selectedUserId >= 0 && !this.isChecking)
  .onClick(() => this.handleFaceCheckIn())
  // 新增按压动画
  .onTouch((event: TouchEvent) => {
    if (this.selectedUserId < 0 || this.isChecking) return;
    if (event.type === TouchType.Down) {
      animateTo({ duration: 80, curve: Curve.FastOutLinearIn }, () => {
        // 按钮下沉：缩小 + 阴影加深
        // 通过在按钮外包裹 Column 并对 Column 做 scale 实现
      });
    } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
      animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        // 弹起恢复
      });
    }
  })
}
```

> **实现注意**：ArkUI Button 的 `onTouch` 直接控制 scale 效果有限，推荐做法是将 Button 包裹在一个 `@State scale: number = 1` 的 Column 中，对 Column 做 `scale(this.scale)` 变换。改动点：在 `Index.ets` 的状态区添加 `scale: number = 1`，然后在 `checkInButton()` 外层包 Column。

具体做法：
```typescript
// 在 Index.ets struct 内添加：
@State buttonScale: number = 1;

// checkInButton 改造：
Column() {
  Button(...) { ... }
  .scale({ x: this.buttonScale, y: this.buttonScale })
}
.width('100%')
.scale({ x: this.buttonScale, y: this.buttonScale })
.onTouch((event) => {
  if (event.type === TouchType.Down) {
    animateTo({ duration: 80 }, () => { this.buttonScale = 0.96; });
  } else {
    animateTo({ duration: 150 }, () => { this.buttonScale = 1; });
  }
})
```

- [ ] **Step 2: 同样改造发起签到按钮（header 中的 Button）**

在 `header()` @Builder 中找到"发起签到"和"结束本场"按钮，同样添加 `onTouch` + `scale` 动画。

- [ ] **Step 3: Commit**

```bash
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets
git commit -m "feat(ui): add button press feedback (scale + shadow) in Index.ets"
```

---

## Task 6: 列表交错入场动画（Stagger Animation）

**Files:**
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets`（recentPanel 中的签到动态列表）
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/RecordListPage.ets`
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/UserListPage.ets`

- [ ] **Step 1: 创建 AnimatedCard 包装组件**

```typescript
/**
 * AnimatedCard.ets — 带交错入场动画的卡片包装器
 * 用法：给 ListItem 或 ForEach 中的行元素包一层 Column，
 * 在 onAppear 时从下方滑入并淡入。
 */
@Component
export struct AnimatedCard {
  @State private translateY: number = 20;
  @State private opacity: number = 0;
  @Prop delay: number = 0;  // 延迟毫秒数，用于 stagger 效果

  aboutToAppear(): void {
    setTimeout(() => {
      animateTo({
        duration: 350,
        curve: Curve.EaseOut,
        delay: this.delay
      }, () => {
        this.translateY = 0;
        this.opacity = 1;
      });
    }, 50);
  }

  build() {
    Column() {
      // 子内容由父组件通过内容投影传入
    }
    .translate({ y: this.translateY })
    .opacity(this.opacity)
  }
}
```

- [ ] **Step 2: 修改 Index.ets — recentPanel 签到动态列表加 stagger 入场**

在 `recentPanel()` 的 `ForEach` 循环中，给每个 `ListItem` 外层包 `AnimatedCard`，delay 参数为索引 × 50ms：

```typescript
ForEach(this.checkInActivities.slice(0, 30), (activity: CheckInActivity, index: number) => {
  ListItem() {
    AnimatedCard({ delay: index * 50 }) {
      Row() {
        // ... 原有内容
      }
      .width('100%')
      .padding({ top: dense ? 8 : 10, bottom: dense ? 8 : 10 })
      .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })
    }
  }
}, (activity: CheckInActivity) => activity.id)
```

- [ ] **Step 3: 修改 RecordListPage.ets — 记录列表 stagger**

在 RecordListPage.ets 的 ForEach 中，同样对 ListItem 包 AnimatedCard，delay = 索引 × 40ms。

- [ ] **Step 4: 修改 UserListPage.ets — 人员列表 stagger**

同上，delay = 索引 × 30ms（人员列表通常更长，30ms 更紧凑）。

- [ ] **Step 5: Commit**

```bash
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/components/AnimatedCard.ets
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/RecordListPage.ets
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/UserListPage.ets
git commit -m "feat(ui): add stagger entrance animation to all list pages"
```

---

## Task 7: 签到结果页——数字滚动动画 + 结果卡片淡入

**Files:**
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets`（resultPanel 改造）

- [ ] **Step 1: 添加数字滚动状态和动画逻辑**

在 Index.ets struct 中添加：
```typescript
@State displayScore: number = 0;  // 动画过程中的显示分数（0.0 ~ 1.0）
@State scoreAnimating: boolean = false;
```

修改 `finishCheckInFailure` / `completeFaceCheckIn` 中设置 `this.lastScore` 后，触发数字滚动动画：
```typescript
// 在 set this.lastScore 后：
this.scoreAnimating = true;
this.displayScore = 0;
animateTo({
  duration: 800,
  curve: Curve.EaseOut,
}, () => {
  this.displayScore = this.lastScore;
});
```

- [ ] **Step 2: 修改 resultPanel() — 结果卡片淡入 + 分数滚动**

在 `resultPanel()` @Builder 中，找到分数显示部分：
```typescript
Text(`${(this.lastScore * 100).toFixed(0)}%`)
  .fontSize(18)
  .fontWeight(FontWeight.Bold)
  .fontColor(this.checkResultSuccess ? '#34C759' : '#FF3B30')
```
替换为：
```typescript
Text(`${Math.round(this.displayScore * 100)}%`)
  .fontSize(18)
  .fontWeight(FontWeight.Bold)
  .fontColor(this.checkResultSuccess ? Colors.success : Colors.danger)
```

在 resultPanel 最外层 Column 上添加入场动画（用 `animateTo` 包裹整个结果卡片区域，当 `showResult` 从 false → true 时触发）：

```typescript
Column() {
  // 原有内容
}
.width('100%')
.padding(12)
.backgroundColor(this.checkResultSuccess ? Colors.successBg : Colors.dangerBg)
.borderRadius(Radius.button)
.margin({ top: 8 })
.opacity(this.showResult ? 1 : 0)
.translate({ y: this.showResult ? 0 : 10 })
.onVisibleAreaChange([0.0, 1.0], (isVisible: boolean) => {
  if (isVisible && this.showResult) {
    animateTo({ duration: 300, curve: Curve.EaseOut }, () => {});
  }
})
```

- [ ] **Step 3: Commit**

```bash
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/Index.ets
git commit -m "feat(ui): add score counter animation and result panel fade-in on Index.ets"
```

---

## Task 8: 设置页——Slider 数值吸附弹跳动效

**Files:**
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/SettingsPage.ets`

- [ ] **Step 1: 读取 SettingsPage.ets 完整代码，找到 lateMinutes Slider 部分**

在 SettingsPage.ets 中找到 lateMinutes 和 faceThreshold 的 Slider 渲染逻辑。

- [ ] **Step 2: 添加弹跳状态**

在 struct 中添加：
```typescript
@State lateBounceY: number = 0;    // lateMinutes 数值标签的 Y 轴弹跳
@State thresholdBounceY: number = 0; // faceThreshold 数值标签的 Y 轴弹跳
```

- [ ] **Step 3: 改造 lateMinutes Slider，添加吸附弹跳**

找到 lateMinutes 的 Row，在数值 Text 后面添加 `.translate({ y: this.lateBounceY })`：
```typescript
Text(`${this.lateMinutes} 分钟`)
  .fontSize(16)
  .fontWeight(FontWeight.Bold)
  .fontColor(Colors.primary)
  .translate({ y: this.lateBounceY })
```

在 Slider 的 `.onChange` 中，当值变化后触发弹跳：
```typescript
.onChange((value: number) => {
  this.lateMinutes = value;
  // 吸附到 5 的倍数
  const snapped = Math.round(value / 5) * 5;
  if (snapped !== this.lateMinutes) {
    this.lateMinutes = snapped;
  }
  // 弹跳效果
  this.lateBounceY = -3;
  animateTo({ duration: 80 }, () => { this.lateBounceY = 2; });
  animateTo({ duration: 100, delay: 80 }, () => { this.lateBounceY = 0; });
})
```

- [ ] **Step 4: 同样改造 faceThreshold Slider**

同上，将 `thresholdBounceY` 应用到 faceThreshold 的数值 Text。

- [ ] **Step 5: Commit**

```bash
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/SettingsPage.ets
git commit -m "feat(ui): add slider snap-to-value bounce animation in SettingsPage.ets"
```

---

## Task 9: 人脸录入页 FaceEnrollPage — 录入成功动效

**Files:**
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/FaceEnrollPage.ets`

- [ ] **Step 1: 读取 FaceEnrollPage.ets，找到录入成功后的结果展示逻辑**

找到录入成功（`enrollSuccess = true`）后的 UI 渲染区域。

- [ ] **Step 2: 添加成功卡片入场动画**

在成功结果显示的 Column 上添加 `animateTo` 淡入 + 上移：
```typescript
@State enrollResultOpacity: number = 0;
@State enrollResultY: number = 20;

// 当 enrollSuccess 变为 true 时触发：
if (enrollSuccess && this.enrollResultOpacity === 0) {
  setTimeout(() => {
    animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
      this.enrollResultOpacity = 1;
      this.enrollResultY = 0;
    });
  }, 100);
}

// 在 build() 中：
Column() {
  // 成功图标 + 文字
}
.opacity(this.enrollResultOpacity)
.translate({ y: this.enrollResultY })
```

- [ ] **Step 3: Commit**

```bash
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/pages/FaceEnrollPage.ets
git commit -m "feat(ui): add enrollment success fade-in animation in FaceEnrollPage.ets"
```

---

## Task 10: 底部导航 AppBottomNav — 图标激活动画

**Files:**
- Modify: `FaceCheck_Merge/Facecheck/entry/src/main/ets/components/AppBottomNav.ets`

- [ ] **Step 1: 改造 navItem — 图标激活时加轻微放大**

在 `navItem` @Builder 中找到 Image，给激活状态添加 scale：

```typescript
Image(icon)
  .width(21)
  .height(21)
  .fillColor(this.active === key ? Colors.primary : Colors.textTertiary)
  .scale({
    x: this.active === key ? 1.15 : 1.0,
    y: this.active === key ? 1.15 : 1.0
  })
  .animation({
    duration: 200,
    curve: Curve.EaseOut
  })
```

Text 文字同步加粗：
```typescript
Text(label)
  .fontSize(11)
  .fontColor(this.active === key ? Colors.primary : Colors.textTertiary)
  .fontWeight(this.active === key ? FontWeight.Medium : FontWeight.Normal)
  .margin({ top: 3 })
```

- [ ] **Step 2: Commit**

```bash
git add FaceCheck_Merge/Facecheck/entry/src/main/ets/components/AppBottomNav.ets
git commit -m "feat(ui): add bottom nav icon scale animation on active state"
```

---

## 自查清单

完成所有任务后，逐项检查：

- [ ] 所有硬编码颜色值已替换为 `DesignTokens` 中的 token
- [ ] 所有卡片（白色背景 Column）已添加 `.shadow(Shadows.card).borderRadius(Radius.card)`
- [ ] 所有按钮已有按压 scale 动画
- [ ] 所有 List 列表已有 stagger 入场动画
- [ ] 状态文字已全部替换为 `StatusPill` 组件
- [ ] 出勤率数字已替换为 `CircleProgress` 组件
- [ ] 签到结果分数有从 0 滚动到目标值的动画
- [ ] Settings 页 Slider 有数值吸附弹跳动效
- [ ] 底部导航图标激活时有 scale 放大动画
- [ ] 运行 `git log --oneline` 确认所有 commit 存在且消息规范

---

## 执行方式选择

**Plan 完成并已保存至 `FaceCheck_Merge/Doc/Plan/PlanUI.md`。**

两个执行选项：

**1. Subagent-Driven（推荐）** — 每个 Task 派发一个独立子 Agent 去执行，Task 之间有审查节点，快速迭代

**2. Inline Execution** — 在本会话中顺序执行所有 Task，带检查点

选择哪个？
