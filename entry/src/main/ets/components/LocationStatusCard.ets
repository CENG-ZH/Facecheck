import { Colors, Radius } from '../utils/DesignTokens';

@Component
export struct LocationStatusCard {
  @Prop locationEnabled: boolean = false;
  @Prop locationName: string = '';
  @Prop radiusMeters: number = 100;
  @Prop latitude: number = 0;
  @Prop longitude: number = 0;
  @Prop accuracy: number = 0;
  @Prop message: string = '';
  @Prop loading: boolean = false;
  @Prop passed: boolean = false;

  private hasPoint(): boolean {
    return this.latitude !== 0 || this.longitude !== 0;
  }

  private getTitle(): string {
    if (!this.locationEnabled) {
      return '位置校验未启用';
    }
    return this.locationName.trim() === '' ? '当前签到点' : this.locationName.trim();
  }

  private getDetail(): string {
    if (!this.locationEnabled) {
      return '本场将沿用普通刷脸签到流程';
    }
    if (this.loading) {
      return '正在获取当前 Pad 位置';
    }
    if (!this.hasPoint()) {
      return '请先使用当前 Pad 位置作为签到点';
    }
    const accuracyText = this.accuracy > 0 ? `，精度约 ${Math.round(this.accuracy)} 米` : '';
    return `半径 ${this.radiusMeters} 米${accuracyText}`;
  }

  private getMessageText(): string {
    if (this.message.trim() !== '') {
      return this.message;
    }
    if (this.locationEnabled && this.hasPoint()) {
      return '每次刷脸前会再次校验当前 Pad 是否仍在范围内';
    }
    return '';
  }

  private getMainColor(): string {
    if (!this.locationEnabled) return Colors.textTertiary;
    if (this.passed || this.hasPoint()) return Colors.success;
    return Colors.warning;
  }

  private getBgColor(): string {
    if (!this.locationEnabled) return Colors.inputBg;
    if (this.passed || this.hasPoint()) return Colors.successBgAlt;
    return Colors.warningBg;
  }

  build() {
    Column() {
      Row() {
        Text(this.locationEnabled ? '定位' : '位置')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.white)
          .textAlign(TextAlign.Center)
          .width(38)
          .height(22)
          .backgroundColor(this.getMainColor())
          .borderRadius(11)
        Column() {
          Text(this.getTitle())
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.textPrimary)
          Text(this.getDetail())
            .fontSize(11)
            .fontColor(Colors.textTertiary)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })
      }
      .width('100%')

      if (this.getMessageText() !== '') {
        Text(this.getMessageText())
          .fontSize(11)
          .fontColor(this.locationEnabled ? Colors.textSecondary : Colors.textTertiary)
          .lineHeight(17)
          .margin({ top: 8 })
          .alignSelf(ItemAlign.Start)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(this.getBgColor())
    .borderRadius(Radius.input)
  }
}
