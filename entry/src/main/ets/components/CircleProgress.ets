/**
 * CircleProgress.ets — 圆环进度条组件
 * 用 Text + 背景/前景双层模拟圆环进度效果，兼容 SDK 6.x 预览模式。
 */
import { Colors } from '../utils/DesignTokens';

@Component
export struct CircleProgress {
  @Prop value: number = 0;
  @Prop size: number = 80;
  @Prop strokeWidth: number = 8;
  @Prop color: string = Colors.primary;
  @Prop label: string = '';
  @Prop showPercent: boolean = true;

  private get diameter(): number {
    return this.size;
  }

  private get radius(): number {
    return (this.size - this.strokeWidth) / 2;
  }

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        Text('')
          .width(this.size)
          .height(this.size)
          .border({
            width: this.strokeWidth,
            color: Colors.border,
            radius: this.radius
          })
        Text(`${Math.round(this.value * 100)}%`)
          .fontSize(Math.round(this.size * 0.22))
          .fontWeight(FontWeight.Bold)
          .fontColor(this.color)
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
