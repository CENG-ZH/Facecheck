import { Logger } from '../utils/Logger';
import { Colors } from '../utils/DesignTokens';

@Component
export struct AppBottomNav {
  @Prop active: string = 'home';

  build() {
    Row() {
      this.navItem('home', '签到', $r('app.media.nav_home'), 'pages/Index')
      this.navItem('users', '人员', $r('app.media.nav_users'), 'pages/UserListPage')
      this.navItem('courses', '教学', $r('app.media.nav_courses'), 'pages/OrganizationPage')
      this.navItem('records', '记录', $r('app.media.nav_records'), 'pages/RecordListPage')
      this.navItem('settings', '设置', $r('app.media.nav_settings'), 'pages/SettingsPage')
    }
    .width('100%')
    .height(58)
    .padding({ left: 8, right: 8 })
    .justifyContent(FlexAlign.SpaceAround)
    .backgroundColor(Colors.card)
    .border({ width: { top: 0.5 }, color: Colors.border })
  }

  @Builder
  private navItem(key: string, label: string, icon: Resource, url: string) {
    Column() {
      Image(icon)
        .width(21)
        .height(21)
        .fillColor(this.active === key ? Colors.primary : Colors.textTertiary)
        .scale({
          x: this.active === key ? 1.15 : 1.0,
          y: this.active === key ? 1.15 : 1.0
        })
        .animation({
          duration: 200,
          curve: Curve.EaseOut
        })
      Text(label)
        .fontSize(11)
        .fontColor(this.active === key ? Colors.primary : Colors.textTertiary)
        .fontWeight(this.active === key ? FontWeight.Medium : FontWeight.Normal)
        .margin({ top: 3 })
    }
    .width('18%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      if (this.active === key) {
        return;
      }
      this.getUIContext().getRouter().replaceUrl({ url: url }).catch((error: Error) => {
        Logger.error('页面导航失败: %{public}s', error.message);
      });
    })
  }
}
