import mediaquery from '@ohos.mediaquery';
import { AppBottomNav } from '../components/AppBottomNav';
import { AppSettings, SettingsService } from '../services/SettingsService';
import { PrivacyService } from '../services/PrivacyService';
import { Logger } from '../utils/Logger';

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
        fontColor: '#FF3B30',
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
    .backgroundColor('#F1F3F5')
  }

  @Builder
  private header() {
    Row() {
      Column() {
        Text('设置')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
        Text('识别策略、活体检测与隐私管理')
          .fontSize(12)
          .fontColor('#989A9C')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height(64)
    .padding({ left: 18, right: 18 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })
  }

  @Builder
  private sectionTitle(title: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(FontWeight.Medium)
      .fontColor('#989A9C')
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
            .fontColor('#182431')
          Text('官方同人判断通过且分数达到阈值才允许签到')
            .fontSize(12)
            .fontColor('#989A9C')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(`${this.faceThreshold}%`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#007DFF')
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
        .selectedColor('#007DFF')
        .margin({ top: 10 })
        .onChange((value: number) => {
          this.faceThreshold = Math.round(value);
        })
        .onChangeEnd((value: number) => {
          const newVal = Math.round(value);
          if (newVal !== this.faceThreshold) {
            this.faceThreshold = newVal;
            this.settingsService.setFaceThreshold(newVal).catch((error: Error) => {
              Logger.error('保存人脸阈值失败: %{public}s', error.message);
            });
            this.thresholdBounceY = -3;
            animateTo({ duration: 80 }, () => { this.thresholdBounceY = 2; });
            animateTo({ duration: 100, delay: 80 }, () => { this.thresholdBounceY = 0; });
          }
        })
      Row() {
        Text('宽松 60%')
          .fontSize(10)
          .fontColor('#989A9C')
        Blank()
        Text('严格 95%')
          .fontSize(10)
          .fontColor('#989A9C')
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
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
            .fontColor('#182431')
          Text('场次开始后超过该时间记为迟到')
            .fontSize(12)
            .fontColor('#989A9C')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Text(`${this.lateMinutes} 分钟`)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#F59E0B')
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
        .selectedColor('#F59E0B')
        .margin({ top: 10 })
        .onChange((value: number) => {
          this.lateMinutes = Math.round(value);
        })
        .onChangeEnd((value: number) => {
          const newVal = Math.round(value / 5) * 5;
          if (newVal !== this.lateMinutes) {
            this.lateMinutes = newVal;
            this.settingsService.setLateMinutes(newVal).catch((error: Error) => {
              Logger.error('保存迟到时间失败: %{public}s', error.message);
            });
            this.lateBounceY = -3;
            animateTo({ duration: 80 }, () => { this.lateBounceY = 2; });
            animateTo({ duration: 100, delay: 80 }, () => { this.lateBounceY = 0; });
          }
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ bottom: 8 })
  }

  @Builder
  private livenessPanel() {
    Row() {
      Column() {
        Text('交互式活体检测')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#182431')
        Text('检测时临时锁定竖屏，结束后恢复进入前方向')
          .fontSize(12)
          .fontColor('#989A9C')
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Toggle({ type: ToggleType.Switch, isOn: this.enableLiveness })
        .selectedColor('#007DFF')
        .onChange((isOn: boolean) => {
          this.enableLiveness = isOn;
          this.settingsService.setEnableLiveness(isOn).catch((error: Error) => {
            Logger.error('保存活体设置失败: %{public}s', error.message);
          });
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ bottom: 8 })
  }

  @Builder
  private systemPanel() {
    Column() {
      this.infoRow('应用版本', '1.1.0')
      Divider().color('#E5E5E5').margin({ top: 12, bottom: 12 })
      this.infoRow('界面框架', 'ArkTS + ArkUI')
      Divider().color('#E5E5E5').margin({ top: 12, bottom: 12 })
      this.infoRow('人脸能力', 'Core Vision Kit')
      Divider().color('#E5E5E5').margin({ top: 12, bottom: 12 })
      this.infoRow('数据存储', 'ArkData RDB v3')
      Divider().color('#E5E5E5').margin({ top: 12, bottom: 12 })
      this.infoRow('屏幕方向', '跟随系统自动旋转')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ bottom: 8 })
  }

  @Builder
  private privacyPanel() {
    Column() {
      Text('本地敏感数据')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#182431')
        .alignSelf(ItemAlign.Start)
      Text('人脸照片与考勤数据仅保存在应用沙箱。清除后保留人员、班级和课程基础信息。')
        .fontSize(12)
        .fontColor('#989A9C')
        .lineHeight(19)
        .margin({ top: 5, bottom: 12 })
      Button(this.isClearing ? '正在清除' : '清除全部人脸与考勤数据')
        .width('100%')
        .height(40)
        .fontSize(13)
        .fontColor('#FF3B30')
        .backgroundColor('#FFF1F0')
        .borderRadius(6)
        .enabled(!this.isClearing)
        .onClick(() => this.confirmClearData())
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
    .margin({ bottom: 8 })
  }

  @Builder
  private aboutPanel() {
    Column() {
      Text('FaceCheck · 一起刷脸签到')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor('#182431')
      Text('面向课堂考勤的 HarmonyOS 原生应用，支持课程名单快照、人脸比对、活体检测与横竖屏自适应。')
        .fontSize(12)
        .fontColor('#989A9C')
        .lineHeight(19)
        .margin({ top: 7 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(8)
  }

  @Builder
  private infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#989A9C')
        .layoutWeight(1)
      Text(value)
        .fontSize(13)
        .fontColor('#182431')
    }
    .width('100%')
  }
}
