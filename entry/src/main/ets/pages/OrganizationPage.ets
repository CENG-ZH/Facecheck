import mediaquery from '@ohos.mediaquery';
import { AppBottomNav } from '../components/AppBottomNav';
import { OrganizationService } from '../services/OrganizationService';
import { AdminClass, Course } from '../models/OrganizationModel';
import { Logger } from '../utils/Logger';
import { Shadows, Radius, Colors } from '../utils/DesignTokens';
import { AnimatedCard } from '../components/AnimatedCard';
import { FaceEnrollButton } from '../components/FaceEnrollButton';

@Entry
@Component
struct OrganizationPage {
  @State classes: AdminClass[] = [];
  @State courses: Course[] = [];
  @State compactMode: boolean = false;
  @State selectedTab: number = 0;
  @State showClassDialog: boolean = false;
  @State showCourseDialog: boolean = false;
  @State className: string = '';
  @State classGrade: string = '';
  @State classMajor: string = '';
  @State courseCode: string = '';
  @State courseName: string = '';

  private organizationService: OrganizationService = new OrganizationService();
  private compactListener?: mediaquery.MediaQueryListener;

  async aboutToAppear(): Promise<void> {
    this.compactListener = this.getUIContext().getMediaQuery().matchMediaSync('(width < 600vp)');
    this.compactMode = this.compactListener.matches;
    this.compactListener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.compactMode = result.matches;
    });
    await this.loadData();
  }

  aboutToDisappear(): void {
    this.compactListener?.off('change');
  }

  private async loadData(): Promise<void> {
    try {
      this.classes = await this.organizationService.getClasses();
      this.courses = await this.organizationService.getCourses();
    } catch (error) {
      Logger.error('加载教学组织数据失败: %{public}s', JSON.stringify(error));
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2200 });
  }

  private async createClass(): Promise<void> {
    try {
      await this.organizationService.createClass(this.className, this.classGrade, this.classMajor);
      this.showClassDialog = false;
      this.className = '';
      this.classGrade = '';
      this.classMajor = '';
      await this.loadData();
      this.showToast('班级已创建');
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '创建班级失败');
    }
  }

  private async createCourse(): Promise<void> {
    try {
      await this.organizationService.createCourse(this.courseCode, this.courseName);
      this.showCourseDialog = false;
      this.courseCode = '';
      this.courseName = '';
      await this.loadData();
      this.showToast('课程已创建');
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '创建课程失败');
    }
  }

  private confirmArchiveClass(item: AdminClass): void {
    this.getUIContext().showAlertDialog({
      title: '归档班级',
      message: `归档“${item.name}”后，新建学生时将不再显示该班级。历史考勤不会受影响。`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '归档',
        fontColor: Colors.danger,
        action: () => {
          this.organizationService.archiveClass(item.id).then(() => {
            this.loadData();
          }).catch((error: Error) => {
            this.showToast(error.message);
          });
        }
      }
    });
  }

  private confirmArchiveCourse(item: Course): void {
    this.getUIContext().showAlertDialog({
      title: '归档课程',
      message: `归档”${item.name}”后不能再发起新签到，历史场次与报表会保留。`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '归档',
        fontColor: Colors.danger,
        action: () => {
          this.organizationService.archiveCourse(item.id).then(() => {
            this.loadData();
          }).catch((error: Error) => {
            this.showToast(error.message);
          });
        }
      }
    });
  }

  build() {
    Stack() {
      Column() {
        this.header()

        if (this.compactMode) {
          Row() {
            this.tabButton('班级', 0, () => this.classes.length)
            this.tabButton('课程', 1, () => this.courses.length)
          }
          .width('100%')
          .height(48)
          .padding({ left: 16, right: 16 })
          .backgroundColor(Colors.card)
          .border({ width: { bottom: 0.5 }, color: Colors.border })

          if (this.selectedTab === 0) {
            this.classPanel()
          } else {
            this.coursePanel()
          }
        } else {
          Row() {
            this.classPanel()
            Divider().vertical(true).height('100%').color(Colors.border)
            this.coursePanel()
          }
          .layoutWeight(1)
          .width('100%')
          .padding(16)
        }

        AppBottomNav({ active: 'courses' })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Colors.bg)

      if (this.showClassDialog) {
        this.classDialog()
      }
      if (this.showCourseDialog) {
        this.courseDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private header() {
    Row() {
      Column() {
        Text('教学组织')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
        Text('班级归属、课程与选课关系')
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      FaceEnrollButton() {
        Button() {
          Row() {
            Image($r('app.media.icon_add'))
              .width(17)
              .height(17)
              .fillColor(Colors.white)
            Text(this.compactMode && this.selectedTab === 1 ? '课程' : '班级')
              .fontSize(14)
              .fontColor(Colors.white)
              .margin({ left: 5 })
          }
        }
        .height(38)
        .padding({ left: 13, right: 13 })
        .type(ButtonType.Normal)
        .borderRadius(6)
        .backgroundColor(Colors.primary)
        .onClick(() => {
          if (this.compactMode && this.selectedTab === 1) {
            this.showCourseDialog = true;
          } else {
            this.showClassDialog = true;
          }
        })
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 18, right: 18 })
    .backgroundColor(Colors.card)
    .border({ width: { bottom: 0.5 }, color: Colors.border })
  }

  @Builder
  private tabButton(label: string, index: number, count: () => number) {
    Column() {
      Text(`${label} ${count()}`)
        .fontSize(14)
        .fontWeight(this.selectedTab === index ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(this.selectedTab === index ? Colors.primary : Colors.textTertiary)
      Divider()
        .width(44)
        .strokeWidth(2)
        .color(this.selectedTab === index ? Colors.primary : 'rgba(0,0,0,0)')
        .margin({ top: 9 })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.End)
    .onClick(() => {
      this.selectedTab = index;
    })
  }

  @Builder
  private classPanel() {
    Column() {
      if (!this.compactMode) {
        this.panelTitle('行政班级', () => `${this.classes.length} 个有效班级`, () => {
          this.showClassDialog = true;
        })
      }
      List() {
        ForEach(this.classes, (item: AdminClass, index: number) => {
          ListItem() {
            AnimatedCard({ delay: Math.min(index, 8) * 35 }) {
              Row() {
              Column() {
                Text(item.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Colors.textPrimary)
                Text([item.grade, item.major].filter((value: string) => value !== '').join(' · ') || '未填写年级与专业')
                  .fontSize(12)
                  .fontColor(Colors.textTertiary)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button('归档')
                .height(32)
                .fontSize(12)
                .fontColor(Colors.danger)
                .backgroundColor(Colors.dangerBg)
                .borderRadius(6)
                .onClick(() => this.confirmArchiveClass(item))
            }
            .width('100%')
            .padding(15)
              .backgroundColor(Colors.card)
            }
          }
        }, (item: AdminClass) => item.id.toString())
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0.5, color: Colors.border, startMargin: 15, endMargin: 15 })
    }
    .layoutWeight(1)
    .height('100%')
    .margin(this.compactMode ? 0 : { right: 8 })
    .backgroundColor(Colors.card)
    .borderRadius(12)
    .shadow(Shadows.card)
  }

  @Builder
  private coursePanel() {
    Column() {
      if (!this.compactMode) {
        this.panelTitle('课程', () => `${this.courses.length} 门有效课程`, () => {
          this.showCourseDialog = true;
        })
      }
      List() {
        ForEach(this.courses, (item: Course, index: number) => {
          ListItem() {
            AnimatedCard({ delay: Math.min(index, 8) * 35 }) {
              Row() {
              Column() {
                Text(item.name)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(Colors.textPrimary)
                Text(item.code)
                  .fontSize(12)
                  .fontColor(Colors.primary)
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button('归档')
                .height(32)
                .fontSize(12)
                .fontColor(Colors.danger)
                .backgroundColor(Colors.dangerBg)
                .borderRadius(6)
                .onClick(() => this.confirmArchiveCourse(item))
            }
            .width('100%')
            .padding(15)
              .backgroundColor(Colors.card)
            }
          }
        }, (item: Course) => item.id.toString())
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0.5, color: Colors.border, startMargin: 15, endMargin: 15 })
    }
    .layoutWeight(1)
    .height('100%')
    .margin(this.compactMode ? 0 : { left: 8 })
    .backgroundColor(Colors.card)
    .borderRadius(12)
    .shadow(Shadows.card)
  }

  @Builder
  private panelTitle(title: string, subtitle: () => string, action: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
        Text(subtitle())
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 3 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      FaceEnrollButton() {
        Button('新增')
          .height(34)
          .fontSize(13)
          .fontColor(Colors.primary)
          .backgroundColor(Colors.primaryBg)
          .borderRadius(6)
          .onClick(action)
      }
    }
    .width('100%')
    .padding(15)
    .border({ width: { bottom: 0.5 }, color: Colors.border })
  }

  @Builder
  private classDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.36)')
        .onClick(() => { this.showClassDialog = false; })
      Column() {
        Text('新增班级')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
          .margin({ bottom: 18 })
        TextInput({ placeholder: '班级名称', text: this.className })
          .width('100%')
          .height(42)
          .onChange((value: string) => { this.className = value; })
        TextInput({ placeholder: '年级，例如 2024级', text: this.classGrade })
          .width('100%')
          .height(42)
          .margin({ top: 10 })
          .onChange((value: string) => { this.classGrade = value; })
        TextInput({ placeholder: '专业', text: this.classMajor })
          .width('100%')
          .height(42)
          .margin({ top: 10, bottom: 18 })
          .onChange((value: string) => { this.classMajor = value; })
        this.dialogActions(() => { this.showClassDialog = false; }, () => this.createClass())
      }
      .width(this.compactMode ? '88%' : 400)
      .padding(22)
      .backgroundColor(Colors.card)
      .shadow(Shadows.card)
      .borderRadius(Radius.card)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private courseDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.36)')
        .onClick(() => { this.showCourseDialog = false; })
      Column() {
        Text('新增课程')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
          .margin({ bottom: 18 })
        TextInput({ placeholder: '课程编号，例如 HM101', text: this.courseCode })
          .width('100%')
          .height(42)
          .onChange((value: string) => { this.courseCode = value; })
        TextInput({ placeholder: '课程名称', text: this.courseName })
          .width('100%')
          .height(42)
          .margin({ top: 10, bottom: 18 })
          .onChange((value: string) => { this.courseName = value; })
        this.dialogActions(() => { this.showCourseDialog = false; }, () => this.createCourse())
      }
      .width(this.compactMode ? '88%' : 400)
      .padding(22)
      .backgroundColor(Colors.card)
      .shadow(Shadows.card)
      .borderRadius(Radius.card)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private dialogActions(cancel: () => void, confirm: () => void) {
    Row() {
      Column() {
        FaceEnrollButton() {
          Button('取消')
            .width('100%')
            .height(42)
            .fontColor(Colors.textPrimary)
            .backgroundColor(Colors.inputBg)
            .borderRadius(6)
            .onClick(cancel)
        }
      }
      .layoutWeight(1)
      .margin({ right: 6 })
      Column() {
        FaceEnrollButton() {
          Button('创建')
            .width('100%')
            .height(42)
            .backgroundColor(Colors.primary)
            .borderRadius(6)
            .onClick(confirm)
        }
      }
      .layoutWeight(1)
      .margin({ left: 6 })
    }
    .width('100%')
  }
}
