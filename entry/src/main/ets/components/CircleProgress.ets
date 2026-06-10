/**
 * CircleProgress.ets - 出勤率圆环
 * value 使用 0.0~1.0 的比例值，组件内部统一处理非法值并转换为百分比。
 */
import { Colors } from '../utils/DesignTokens';

@Component
export struct CircleProgress {
  @Prop value: number = 0;
  @Prop circleSize: number = 80;
  @Prop strokeWidth: number = 8;
  @Prop color: string = Colors.success;
  @Prop label: string = '';
  @Prop showPercent: boolean = true;

  private getSafeValue(): number {
    if (!(this.value > 0)) {
      return 0;
    }
    if (this.value >= 1) {
      return 1;
    }
    return this.value;
  }

  private getPercent(): number {
    return Math.round(this.getSafeValue() * 100);
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        // 灰色底环始终渲染，保证 0% 时仍有完整的圆环轮廓。
        Progress({
          value: 100,
          total: 100,
          type: ProgressType.Ring
        })
          .width(this.circleSize)
          .height(this.circleSize)
          .color(Colors.border)
          .style({
            strokeWidth: this.strokeWidth,
            shadow: false,
            status: ProgressStatus.PROGRESSING,
            enableScanEffect: false,
            enableSmoothEffect: false
          })

        // 绿色进度环始终保留在组件树中，数值变化时才能产生连续动画。
        Progress({
          value: 0,
          total: 100,
          type: ProgressType.Ring
        })
          .value(this.getPercent())
          .width(this.circleSize)
          .height(this.circleSize)
          .color(this.color)
          .style({
            strokeWidth: this.strokeWidth,
            shadow: false,
            status: ProgressStatus.PROGRESSING,
            enableScanEffect: false,
            enableSmoothEffect: true
          })
          .animation({
            duration: 500,
            curve: Curve.EaseOut
          })

        if (this.showPercent) {
          Text(`${this.getPercent()}%`)
            .fontSize(Math.round(this.circleSize * 0.22))
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getPercent() > 0 ? this.color : Colors.textSecondary)
        }
      }
      .width(this.circleSize)
      .height(this.circleSize)

      if (this.label !== '') {
        Text(this.label)
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 8 })
      }
    }
  }
}
