/**
 * AnimatedCard.ets — 带入场动画的卡片包装器
 * 支持 @BuilderParam 内容投影，在 aboutToAppear 时从下方滑入并淡入
 */
@Component
export struct AnimatedCard {
  @State private translateY: number = 20;
  @State private opacity: number = 0;
  @Prop delay: number = 0; // 延迟毫秒数，用于 stagger 效果
  @BuilderParam content: () => void = () => {};

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
      this.content()
    }
    .translate({ y: this.translateY })
    .opacity(this.opacity)
  }
}
