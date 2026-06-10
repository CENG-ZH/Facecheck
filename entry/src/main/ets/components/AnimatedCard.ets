/**
 * AnimatedCard.ets — 带入场动画的卡片包装器
 * 支持 @BuilderParam 内容投影，组件进入可视区域时触发滑入淡入动画。
 */
@Component
export struct AnimatedCard {
  @State private cardTranslateY: number = 20;
  @State private cardOpacity: number = 0;
  @Prop delay: number = 0;
  @BuilderParam content: () => void;
  private timerId: number = -1;
  private hasAnimated: boolean = false;

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    Column() {
      this.content()
    }
    .translate({ y: this.cardTranslateY })
    .opacity(this.cardOpacity)
    .onVisibleAreaChange([0], (isExpanding: boolean, ratio: number) => {
      if (isExpanding && ratio > 0 && !this.hasAnimated) {
        this.hasAnimated = true;
        this.timerId = setTimeout(() => {
          this.getUIContext().animateTo({
            duration: 350,
            curve: Curve.EaseOut,
            delay: this.delay
          }, () => {
            this.cardTranslateY = 0;
            this.cardOpacity = 1;
          });
          this.timerId = -1;
        }, 50);
      }
    })
  }
}
