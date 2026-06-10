import mediaquery from '@ohos.mediaquery';
import { image } from '@kit.ImageKit';
import { UserService } from '../services/UserService';
import { UserModel } from '../models/UserModel';
import { FaceVisionAdapter } from '../kits/FaceVisionAdapter';
import { CameraAdapter } from '../kits/CameraAdapter';
import { Logger } from '../utils/Logger';
import { Colors, Radius, Shadows } from '../utils/DesignTokens';
import { FaceEnrollButton } from '../components/FaceEnrollButton';

@Entry
@Component
struct FaceEnrollPage {
  @State userId: number = -1;
  @State userName: string = '';
  @State currentUser: UserModel | null = null;
  @State capturedImage: image.PixelMap | undefined = undefined;
  @State compactMode: boolean = false;
  @State isEnrolling: boolean = false;
  @State enrollSuccess: boolean = false;
  @State enrollMessage: string = '';
  @State currentStep: number = -1;
  @State stepText: string = '';
  @State enrollResultOpacity: number = 0;
  @State enrollResultY: number = 20;

  private userService: UserService = new UserService();
  private compactListener?: mediaquery.MediaQueryListener;

  async aboutToAppear(): Promise<void> {
    const params = this.getUIContext().getRouter().getParams() as Record<string, number | string>;
    this.userId = params?.['userId'] as number || -1;
    this.userName = params?.['userName'] as string || '';
    this.compactListener = this.getUIContext().getMediaQuery().matchMediaSync('(width < 600vp)');
    this.compactMode = this.compactListener.matches;
    this.compactListener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.compactMode = result.matches;
    });
    await this.loadUser();
    FaceVisionAdapter.initDetector().catch((error: Error) => {
      Logger.error('人脸检测引擎初始化失败: %{public}s', error.message);
    });
  }

  aboutToDisappear(): void {
    this.compactListener?.off('change');
    this.capturedImage?.release();
    this.capturedImage = undefined;
    FaceVisionAdapter.releaseDetector();
  }

  private async loadUser(): Promise<void> {
    if (this.userId > 0) {
      this.currentUser = await this.userService.getUserById(this.userId);
      if (this.currentUser) {
        this.userName = this.currentUser.name;
      }
    }
  }

  private async handleEnroll(): Promise<void> {
    if (this.userId <= 0 || this.isEnrolling) return;
    this.isEnrolling = true;
    this.enrollSuccess = false;
    this.enrollMessage = '';
    this.currentStep = 0;
    this.stepText = '打开前置相机';
    this.enrollResultOpacity = 0;
    this.enrollResultY = 20;

    try {
      const context = this.getUIContext().getHostContext();
      if (!context) {
        throw new Error('无法获取应用上下文');
      }
      const pixelMap = await CameraAdapter.capturePhoto(context);
      if (!pixelMap) {
        this.enrollMessage = '未拍摄照片，请重试';
        return;
      }

      this.capturedImage?.release();
      this.capturedImage = pixelMap;
      this.currentStep = 1;
      this.stepText = '检测人脸';
      // CameraPicker 返回时页面会重新显示，确保检测器已重新初始化。
      await FaceVisionAdapter.initDetector();
      const detection = await FaceVisionAdapter.detect(pixelMap);
      if (!detection.hasFace || detection.faceCount !== 1 || !detection.isFrontal) {
        this.enrollMessage = detection.message;
        return;
      }

      this.currentStep = 2;
      this.stepText = '评估图像质量';
      const fileName = `face_${this.userId}_${Date.now()}.jpg`;
      const savedPath = await CameraAdapter.savePixelMap(context, pixelMap, fileName);

      this.currentStep = 3;
      this.stepText = '保存人脸资料';
      await this.userService.updateFaceImage(this.userId, savedPath);
      this.enrollSuccess = true;
      this.enrollMessage = '已检测到单人正面人脸，注册照片保存成功';
      await this.loadUser();
      this.getUIContext().getPromptAction().showToast({ message: '人脸录入成功', duration: 2000 });
      setTimeout(() => {
        this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
          this.enrollResultOpacity = 1;
          this.enrollResultY = 0;
        });
      }, 100);
    } catch (error) {
      this.enrollSuccess = false;
      this.enrollMessage = error instanceof Error ? error.message : '人脸录入失败';
      Logger.error('人脸录入失败: %{public}s', JSON.stringify(error));
    } finally {
      // 失败路径也需要显示消息（成功路径已有上方的 fade-in 动画）
      if (this.enrollMessage !== '' && !this.enrollSuccess) {
        setTimeout(() => {
          this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
            this.enrollResultOpacity = 1;
            this.enrollResultY = 0;
          });
        }, 100);
      }
      this.isEnrolling = false;
      this.stepText = '';
    }
  }

  build() {
    Column() {
      this.header()
      if (this.compactMode) {
        Scroll() {
          Column() {
            this.userPanel()
            this.capturePanel()
            this.guidePanel()
            this.actionPanel()
          }
          .width('100%')
          .padding(12)
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        Row() {
          Column() {
            this.userPanel()
            this.guidePanel()
            this.actionPanel()
          }
          .width('42%')
          .height('100%')
          .padding(16)
          .backgroundColor(Colors.bg)
          Column() {
            this.capturePanel()
          }
          .layoutWeight(1)
          .height('100%')
          .padding(16)
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.bg)
  }

  @Builder
  private header() {
    Row() {
      Button() {
        Image($r('app.media.icon_back'))
          .width(21)
          .height(21)
          .fillColor(Colors.textPrimary)
      }
      .width(38)
      .height(38)
      .type(ButtonType.Normal)
      .backgroundColor('rgba(0,0,0,0)')
      .onClick(() => this.getUIContext().getRouter().back())
      Text('人脸录入')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.textPrimary)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('')
        .width(38)
    }
    .width('100%')
    .height(60)
    .padding({ left: 12, right: 12 })
    .backgroundColor(Colors.card)
    .border({ width: { bottom: 0.5 }, color: Colors.border })
  }

  @Builder
  private userPanel() {
    Row() {
      Text(this.userName.charAt(0) || '?')
        .width(50)
        .height(50)
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.white)
        .textAlign(TextAlign.Center)
        .backgroundColor(Colors.primary)
        .borderRadius(25)
        .margin({ right: 13 })
      Column() {
        Text(this.userName)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
        if (this.currentUser) {
          Text(`${this.currentUser.studentNo} · ${this.currentUser.className}`)
            .fontSize(12)
            .fontColor(Colors.textTertiary)
            .margin({ top: 5 })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(this.currentUser?.faceEnrolled ? '已录入' : '未录入')
        .fontSize(12)
        .fontColor(this.currentUser?.faceEnrolled ? Colors.success : Colors.danger)
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor(this.currentUser?.faceEnrolled ? Colors.successBg : Colors.dangerBg)
        .borderRadius(4)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.card)
    .borderRadius(Radius.card)
    .shadow(Shadows.card)
    .margin({ bottom: 10 })
  }

  @Builder
  private capturePanel() {
    Column() {
      Stack() {
        if (this.capturedImage) {
          Image(this.capturedImage)
            .width('100%')
            .height(this.compactMode ? 300 : '70%')
            .objectFit(ImageFit.Contain)
            .borderRadius(6)
        } else {
          Column() {
            Image($r('app.media.icon_camera'))
              .width(54)
              .height(54)
              .fillColor(Colors.textTertiary)
            Text('拍照后在此预览')
              .fontSize(15)
              .fontColor(Colors.textPrimary)
              .margin({ top: 12 })
            Text('保持正脸、单人、光线均匀')
              .fontSize(12)
              .fontColor(Colors.textTertiary)
              .margin({ top: 5 })
          }
          .width('100%')
          .height(this.compactMode ? 300 : '70%')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .backgroundColor(Colors.card)
      .borderRadius(8)
      .border({ width: 1, color: Colors.border })

      this.progressBar()

      if (this.enrollMessage !== '') {
        Column() {
          Text(this.enrollSuccess ? '录入成功' : '录入未完成')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.enrollSuccess ? Colors.success : Colors.danger)
          Text(this.enrollMessage)
            .fontSize(12)
            .fontColor(Colors.textPrimary)
            .margin({ top: 5 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(13)
        .backgroundColor(this.enrollSuccess ? Colors.successBg : Colors.dangerBg)
        .borderRadius(6)
        .margin({ top: 10 })
        .opacity(this.enrollResultOpacity)
        .translate({ y: this.enrollResultY })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Colors.card)
    .borderRadius(Radius.card)
    .shadow(Shadows.card)
    .margin({ bottom: 10 })
  }

  @Builder
  private progressBar() {
    Row() {
      this.stepNode(0, '拍照')
      this.stepLine(1)
      this.stepNode(1, '检测')
      this.stepLine(2)
      this.stepNode(2, '质量')
      this.stepLine(3)
      this.stepNode(3, '保存')
    }
    .width('100%')
    .padding({ top: 14, bottom: 2 })
  }

  @Builder
  private stepNode(index: number, label: string) {
    Column() {
      Text(index < this.currentStep ? '✓' : (index + 1).toString())
        .width(25)
        .height(25)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(index <= this.currentStep ? Colors.white : Colors.textTertiary)
        .textAlign(TextAlign.Center)
        .backgroundColor(index <= this.currentStep ? Colors.primary : Colors.border)
        .borderRadius(13)
      Text(label)
        .fontSize(10)
        .fontColor(index <= this.currentStep ? Colors.primary : Colors.textTertiary)
        .margin({ top: 4 })
    }
  }

  @Builder
  private stepLine(targetIndex: number) {
    Divider()
      .layoutWeight(1)
      .strokeWidth(2)
      .color(targetIndex <= this.currentStep ? Colors.primary : Colors.border)
      .margin({ left: 4, right: 4, bottom: 14 })
  }

  @Builder
  private guidePanel() {
    Column() {
      Text('录入要求')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.textPrimary)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 10 })
      this.guideRow('01', '面部正对摄像头，不要侧脸或低头')
      this.guideRow('02', '摘下帽子、墨镜等明显遮挡物')
      this.guideRow('03', '保证画面只有一人且光线均匀')
      this.guideRow('04', '照片仅保存在应用本地沙箱')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.card)
    .borderRadius(Radius.card)
    .shadow(Shadows.card)
    .margin({ bottom: 10 })
  }

  @Builder
  private guideRow(index: string, text: string) {
    Row() {
      Text(index)
        .fontSize(11)
        .fontColor(Colors.primary)
        .width(28)
      Text(text)
        .fontSize(12)
        .fontColor(Colors.textPrimary)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }

  @Builder
  private actionPanel() {
    FaceEnrollButton({ animationEnabled: !this.isEnrolling }) {
      Button() {
        Row() {
          Image($r('app.media.icon_camera'))
            .width(19)
            .height(19)
            .fillColor(Colors.white)
          Text(this.isEnrolling ? (this.stepText || '处理中') :
            (this.currentUser?.faceEnrolled ? '重新录入人脸' : '拍照录入人脸'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.white)
            .margin({ left: 7 })
        }
      }
      .width('100%')
      .height(48)
      .type(ButtonType.Normal)
      .backgroundColor(this.isEnrolling ? Colors.disabled : Colors.primary)
      .borderRadius(6)
      .shadow(this.isEnrolling ? { radius: 0, color: Color.Transparent } : Shadows.button)
      .enabled(!this.isEnrolling)
      .onClick(() => this.handleEnroll())
    }
  }
}
