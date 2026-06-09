/**
 * CircleProgress.ets — 圆环进度条组件
 * 用 Canvas 精确绘制从 12 点钟方向开始的顺时针进度弧。
 */
import { Colors } from '../utils/DesignTokens';
import drawing from '@kit.ArkGraphics2D';

@Component
export struct CircleProgress {
  @Prop value: number = 0;
  @Prop size: number = 80;
  @Prop strokeWidth: number = 8;
  @Prop color: string = Colors.primary;
  @Prop label: string = '';
  @Prop showPercent: boolean = true;

  build() {
    Column() {
      Stack() {
        Canvas(new drawing.CanvasRenderingContext2D())
          .width(this.size)
          .height(this.size)
          .onReady((ctx: drawing.CanvasRenderingContext2D) => {
            const r: number = (this.size - this.strokeWidth) / 2;
            const cx: number = this.size / 2;
            const cy: number = this.size / 2;
            // 背景整圆
            ctx.strokeStyle = Colors.border;
            ctx.lineWidth = this.strokeWidth;
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, Math.PI * 2);
            ctx.stroke();
            // 进度弧：从 12 点钟方向（-π/2）顺时针走完 value 比例
            if (this.value > 0) {
              ctx.strokeStyle = this.color;
              ctx.lineWidth = this.strokeWidth;
              ctx.lineCap = drawing.LineCap.LineCapRound;
              ctx.beginPath();
              ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * this.value);
              ctx.stroke();
            }
          })
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
