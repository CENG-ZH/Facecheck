/**
 * AnimatedCard.ets — 带入场动画的卡片包装器
 * 支持 @BuilderParam 内容投影，组件可见时触发滑入淡入动画。
 */
@Component
export struct AnimatedCard {
  @State private translateY: number = 20;
  @State private opacity: number = 0;
  @Prop delay: number = 0;
  @BuilderParam content: () => void = () => {};

  build() {
    Column() {
      this.content()
    }
    .translate({ y: this.translateY })
    .opacity(this.opacity)
    .onVisibleAreaChange([true, false], (isVisible: boolean, currentRatio: number) => {
      if (isVisible && currentRatio > 0 && this.translateY !== 0) {
        const d: number = this.delay;
        setTimeout(() => {
          animateTo({
            duration: 350,
            curve: Curve.EaseOut,
            delay: d
          }, () => {
            this.translateY = 0;
            this.opacity = 1;
          });
        }, 50);
      }
    })
  }
}
