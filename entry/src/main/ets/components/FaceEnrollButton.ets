/**
 * FaceEnrollButton.ets — 带按压反馈的按钮包装器
 * 包装任意 Button 或其他可点击组件，自动添加 scale 按压动画。
 * 通过 animationEnabled 属性控制动画是否生效（禁用状态下不做缩放）。
 */
@Component
export struct FaceEnrollButton {
  @BuilderParam content: () => void;
  @Prop animationEnabled: boolean = true;
  @State private pressScale: number = 1;

  build() {
    Column() {
      this.content()
    }
    .scale({ x: this.animationEnabled ? this.pressScale : 1, y: this.animationEnabled ? this.pressScale : 1 })
    .onTouch((event: TouchEvent) => {
      if (!this.animationEnabled) return;
      this.getUIContext().animateTo({
        duration: event.type === TouchType.Down ? 80 : 150,
        curve: Curve.EaseOut
      }, () => {
        this.pressScale = event.type === TouchType.Down ? 0.96 : 1;
      });
    })
  }
}
