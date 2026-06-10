/**
 * StatusPill.ets — 状态胶囊标签
 * 将签到状态（正常/迟到/失败）显示为彩色胶囊标签。
 */
import { Colors } from '../utils/DesignTokens';

export enum StatusType {
  NORMAL = 'normal',
  LATE = 'late',
  FAILED = 'failed',
  ABSENT = 'absent'
}

@Component
export struct StatusPill {
  @Prop status: StatusType = StatusType.NORMAL;
  @Prop text: string = '';

  private getBgColor(): string {
    if (this.status === StatusType.NORMAL) return Colors.successBg;
    if (this.status === StatusType.LATE) return Colors.warningBg;
    if (this.status === StatusType.FAILED) return Colors.dangerBg;
    return Colors.dangerBg; // ABSENT — 红色（同失败）
  }

  private getTextColor(): string {
    if (this.status === StatusType.NORMAL) return Colors.success;
    if (this.status === StatusType.LATE) return Colors.warning;
    if (this.status === StatusType.FAILED) return Colors.danger;
    return Colors.danger; // ABSENT — 红色（同失败）
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
