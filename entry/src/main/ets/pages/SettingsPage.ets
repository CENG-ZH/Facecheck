import mediaquery from '@ohos.mediaquery';
import { AppBottomNav } from '../components/AppBottomNav';
import { AppSettings, SettingsService } from '../services/SettingsService';
import { PrivacyService } from '../services/PrivacyService';
import { Logger } from '../utils/Logger';
import { Colors, Radius, Shadows } from '../utils/DesignTokens';
import { FaceEnrollButton } from '../components/FaceEnrollButton';

@Entry
@Component
struct SettingsPage {
  @State faceThreshold: number = 80;
  @State enableLiveness: boolean = false;
  @State lateMinutes: number = 15;
  @State expandedMode: boolean = false;
  @State isClearing: boolean = false;
  @State lateBounceY: number = 0;
  @State thresholdBounceY: number = 0;

  private settingsService: SettingsService = SettingsService.getInstance();
  private privacyService: PrivacyService = new PrivacyService();
  private expandedListener?: mediaquery.MediaQueryListener;

  aboutToAppear(): void {
    const settings: AppSettings = this.settingsService.getSettings();
    this.faceThreshold = settings.faceThreshold;
    this.enableLiveness = settings.enableLiveness;
    this.lateMinutes = settings.lateMinutes;
    this.expandedListener = this.getUIContext().getMediaQuery().matchMediaSync('(width >= 840vp)');
    this.expandedMode = this.expandedListener.matches;
    this.expandedListener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.expandedMode = result.matches;
    });
  }

  aboutToDisappear(): void {
    this.expandedListener?.off('change');
  }

  private showToast(message: string, duration: number = 2200): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: duration });
  }

  private confirmClearData(): void {
    this.getUIContext().showAlertDialog({
      title: '清除人脸与考勤数据',
      message: '此操作会永久删除全部人脸照片、签到场次和签到记录。班级、课程与人员基本信息会保留，且无法撤销。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '确认清除',
        fontColor: Colors.danger,
        action: () => {
          this.isClearing = true;
          this.privacyService.clearFaceAndAttendanceData().then(() => {
            this.showToast('敏感数据已清除');
          }).catch((error: Error) => {
            Logger.error('清除敏感数据失败: %{public}s', error.message);
            this.showToast('清除失败，请重试');
          }).finally(() => {
            this.isClearing = false;
          });
        }
      }
    });
  }

  build() {
    Column() {
      this.header()
      Scroll() {
        if (this.expandedMode) {
          Row() {
            Column() {
              this.sectionTitle('签到与识别')
              this.faceThresholdPanel()
              this.lateMinutesPanel()
              this.livenessPanel()
            }
            .layoutWeight(1)
            .margin({ right: 8 })
            Column() {
              this.sectionTitle('系统与隐私')
              this.systemPanel()
              this.privacyPanel()
              this.aboutPanel()
            }
            .layoutWeight(1)
            .margin({ left: 8 })
          }
          .width('100%')
          .padding(16)
        } else {
          Column() {
            this.sectionTitle('签到与识别')
            this.faceThresholdPanel()
            this.lateMinutesPanel()
            this.livenessPanel()
            this.sectionTitle('系统与隐私')
            this.systemPanel()
            this.privacyPanel()
            this.aboutPanel()
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 8, bottom: 18 })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)

      AppBottomNav({ active: 'settings' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.bg)
  }

  @Builder
  private header() {
    Row() {
      Column() {
        Text('设置')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
        Text('识别策略、活体检测与隐私管理')
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(64)
    .padding({ left: 18, right: 18 })
    .backgroundColor(Colors.card)
    .border({ width: { bottom: 0.5 }, color: Colors.border })
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor(Colors.textTertiary)
      .alignSelf(ItemAlign.Start)
      .margin({ top: 10, bottom: 8 })
  }

  @Builder
  private faceThresholdPanel() {
    Column() {
      Row() {
        Column() {
          Text('人脸匹配阈值')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.textPrimary)
          Text('官方同人判断通过且分数达到阈值才允许签到')
            .fontSize(12)
            .fontColor(Colors.textTertiary)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(`${this.faceThreshold}%`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.primary)
          .translate({ y: this.thresholdBounceY })
      }
      .width('100%')
      Slider({
        value: this.faceThreshold,
        min: 60,
        max: 95,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .selectedColor(Colors.primary)
        .margin({ top: 10 })
        .onChange((value: number, mode: SliderChangeMode) => {
          const newVal = Math.round(value);
          this.faceThreshold = newVal;
          if (mode === SliderChangeMode.End) {
            this.settingsService.setFaceThreshold(newVal).catch((error: Error) => {
              Logger.error('保存人脸阈值失败: %{public}s', error.message);
            });
            this.thresholdBounceY = -3;
            this.getUIContext().animateTo({ duration: 80 }, () => { this.thresholdBounceY = 2; });
            this.getUIContext().animateTo({ duration: 100, delay: 80 }, () => { this.thresholdBounceY = 0; });
          }
        })
      Row() {
        Text('宽松 60%')
          .fontSize(10)
          .fontColor(Colors.textTertiary)
        Blank()
        Text('严格 95%')
          .fontSize(10)
          .fontColor(Colors.textTertiary)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.card)
    .borderRadius(Radius.card)
    .shadow(Shadows.card)
    .margin({ bottom: 8 })
  }

  @Builder
  private lateMinutesPanel() {
    Column() {
      Row() {
        Column() {
          Text('迟到判定')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.textPrimary)
          Text('场次开始后超过该时间记为迟到')
            .fontSize(12)
            .fontColor(Colors.textTertiary)
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(`${this.lateMinutes} 分钟`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.warning)
          .translate({ y: this.lateBounceY })
      }
      .width('100%')
      Slider({
        value: this.lateMinutes,
        min: 5,
        max: 60,
        step: 5,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .selectedColor(Colors.warning)
        .margin({ top: 10 })
        .onChange((value: number, mode: SliderChangeMode) => {
          const newVal = Math.round(value / 5) * 5;
          this.lateMinutes = newVal;
          if (mode === SliderChangeMode.End) {
            this.settingsService.setLateMinutes(newVal).catch((error: Error) => {
              Logger.error('保存迟到时间失败: %{public}s', error.message);
            });
            this.lateBounceY = -3;
            this.getUIContext().animateTo({ duration: 80 }, () => { this.lateBounceY = 2; });
            this.getUIContext().animateTo({ duration: 100, delay: 80 }, () => { this.lateBounceY = 0; });
          }
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.card)
    .borderRadius(Radius.card)
    .shadow(Shadows.card)
    .margin({ bottom: 8 })
  }

  @Builder
  private livenessPanel() {
    Row() {
      Column() {
        Text('交互式活体检测')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.textPrimary)
        Text('检测时临时锁定竖屏，结束后恢复进入前方向')
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.enableLiveness })
        .selectedColor(Colors.primary)
        .onChange((isOn: boolean) => {
          this.enableLiveness = isOn;
          this.settingsService.setEnableLiveness(isOn).catch((error: Error) => {
            Logger.error('保存活体设置失败: %{public}s', error.message);
          });
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.card)
    .borderRadius(Radius.card)
    .shadow(Shadows.card)
    .margin({ bottom: 8 })
  }

  @Builder
  private systemPanel() {
    Column() {
      this.infoRow('应用版本', '1.1.0')
      Divider().color(Colors.border).margin({ top: 12, bottom: 12 })
      this.infoRow('界面框架', 'ArkTS + ArkUI')
      Divider().color(Colors.border).margin({ top: 12, bottom: 12 })
      this.infoRow('人脸能力', 'Core Vision Kit')
      Divider().color(Colors.border).margin({ top: 12, bottom: 12 })
      this.infoRow('数据存储', 'ArkData RDB v3')
      Divider().color(Colors.border).margin({ top: 12, bottom: 12 })
      this.infoRow('屏幕方向', '跟随系统自动旋转')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.card)
    .borderRadius(Radius.card)
    .shadow(Shadows.card)
    .margin({ bottom: 8 })
  }

  @Builder
  private privacyPanel() {
    Column() {
      Text('本地敏感数据')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Colors.textPrimary)
        .alignSelf(ItemAlign.Start)
      Text('人脸照片与考勤数据仅保存在应用沙箱。清除后保留人员、班级和课程基础信息。')
        .fontSize(12)
        .fontColor(Colors.textTertiary)
        .lineHeight(19)
        .margin({ top: 5, bottom: 12 })
      Column() {
        FaceEnrollButton({ animationEnabled: !this.isClearing }) {
          Button(this.isClearing ? '正在清除' : '清除全部人脸与考勤数据')
            .width('100%')
            .height(40)
            .fontSize(13)
            .fontColor(Colors.danger)
            .backgroundColor(Colors.dangerBg)
            .borderRadius(6)
            .enabled(!this.isClearing)
            .onClick(() => this.confirmClearData())
        }
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(Colors.card)
    .borderRadius(Radius.card)
    .shadow(Shadows.card)
    .margin({ bottom: 8 })
  }

  @Builder
  private aboutPanel() {
    Column() {
      Text('FaceCheck · 一起刷脸签到')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.textPrimary)
      Text('面向课堂考勤的 HarmonyOS 原生应用，支持课程名单快照、人脸比对、活体检测与横竖屏自适应。')
        .fontSize(12)
        .fontColor(Colors.textTertiary)
        .lineHeight(19)
        .margin({ top: 7 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(Colors.card)
    .borderRadius(Radius.card)
    .shadow(Shadows.card)
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(Colors.textTertiary)
        .layoutWeight(1)
      Text(value)
        .fontSize(13)
        .fontColor(Colors.textPrimary)
    }
    .width('100%')
  }
}
