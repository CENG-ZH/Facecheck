import mediaquery from '@ohos.mediaquery';
import { AppBottomNav } from '../components/AppBottomNav';
import { UserService } from '../services/UserService';
import { OrganizationService } from '../services/OrganizationService';
import { UserModel, UserFormData } from '../models/UserModel';
import { AdminClass, Course } from '../models/OrganizationModel';
import { Logger } from '../utils/Logger';
import { AnimatedCard } from '../components/AnimatedCard';
import { Shadows, Radius, Colors } from '../utils/DesignTokens';

@Entry
@Component
struct UserListPage {
  @State users: UserModel[] = [];
  @State classes: AdminClass[] = [];
  @State courses: Course[] = [];
  @State searchKeyword: string = '';
  @State compactMode: boolean = false;
  @State showFormDialog: boolean = false;
  @State editingUser: UserModel | null = null;
  @State formStudentNo: string = '';
  @State formName: string = '';
  @State formClassId: number = 0;
  @State formCourseIds: number[] = [];
  @State userListOpacity: number = 0;
  @State userListTranslateY: number = 0;

  private userService: UserService = new UserService();
  private organizationService: OrganizationService = new OrganizationService();
  private compactListener?: mediaquery.MediaQueryListener;

  async aboutToAppear(): Promise<void> {
    this.compactListener = this.getUIContext().getMediaQuery().matchMediaSync('(width < 600vp)');
    this.compactMode = this.compactListener.matches;
    this.compactListener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.compactMode = result.matches;
    });
    await this.loadReferenceData();
    await this.loadUsers();
    // 触发列表入场动画
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.userListOpacity = 1;
        this.userListTranslateY = 0;
      });
    }, 100);
  }

  onPageShow(): void {
    this.loadUsers();
  }

  aboutToDisappear(): void {
    this.compactListener?.off('change');
  }

  private async loadReferenceData(): Promise<void> {
    this.classes = await this.organizationService.getClasses();
    this.courses = await this.organizationService.getCourses();
    if (this.formClassId <= 0 && this.classes.length > 0) {
      this.formClassId = this.classes[0].id;
    }
  }

  private async loadUsers(): Promise<void> {
    try {
      this.users = this.searchKeyword.trim() === ''
        ? await this.userService.getAllUsers()
        : await this.userService.searchUsers(this.searchKeyword);
    } catch (error) {
      Logger.error('加载人员列表失败: %{public}s', JSON.stringify(error));
    }
  }

  private showToast(message: string): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2200 });
  }

  private getClassName(classId: number): string {
    return this.classes.find((item: AdminClass) => item.id === classId)?.name ?? '未分班';
  }

  private resetForm(): void {
    this.editingUser = null;
    this.formStudentNo = '';
    this.formName = '';
    this.formClassId = this.classes.length > 0 ? this.classes[0].id : 0;
    this.formCourseIds = this.courses.length > 0 ? [this.courses[0].id] : [];
  }

  private openAddDialog(): void {
    this.resetForm();
    this.showFormDialog = true;
  }

  private async openEditDialog(user: UserModel): Promise<void> {
    this.editingUser = user;
    this.formStudentNo = user.studentNo;
    this.formName = user.name;
    this.formClassId = user.classId;
    this.formCourseIds = await this.organizationService.getUserCourseIds(user.id);
    this.showFormDialog = true;
  }

  private toggleCourse(courseId: number): void {
    const index = this.formCourseIds.indexOf(courseId);
    if (index >= 0) {
      this.formCourseIds = this.formCourseIds.filter((id: number) => id !== courseId);
    } else {
      this.formCourseIds = [...this.formCourseIds, courseId];
    }
  }

  private async saveUser(): Promise<void> {
    if (this.formClassId <= 0) {
      this.showToast('请先在教学组织中创建班级');
      return;
    }
    if (this.formCourseIds.length === 0) {
      this.showToast('请至少选择一门课程');
      return;
    }
    const formData: UserFormData = {
      studentNo: this.formStudentNo.trim(),
      name: this.formName.trim(),
      classId: this.formClassId,
      className: this.getClassName(this.formClassId),
      courseIds: this.formCourseIds
    };
    try {
      if (this.editingUser) {
        await this.userService.updateUser(this.editingUser.id, formData);
        this.showToast('人员信息已更新');
      } else {
        await this.userService.registerUser(formData);
        this.showToast('人员已添加');
      }
      this.showFormDialog = false;
      this.resetForm();
      await this.loadUsers();
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '保存失败');
    }
  }

  private confirmArchive(user: UserModel): void {
    this.getUIContext().showAlertDialog({
      title: '归档人员',
      message: `归档“${user.name}”后将不参与新场次，历史签到和人脸资料会保留。`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: {
        value: '归档',
        fontColor: '#FF3B30',
        action: () => {
          this.userService.deleteUser(user.id).then(() => {
            this.showToast('人员已归档');
            this.loadUsers();
          }).catch((error: Error) => {
            this.showToast(error.message);
          });
        }
      }
    });
  }

  private openFaceEnroll(user: UserModel): void {
    this.getUIContext().getRouter().pushUrl({
      url: 'pages/FaceEnrollPage',
      params: { userId: user.id, userName: user.name }
    }).catch((error: Error) => {
      Logger.error('打开人脸录入页失败: %{public}s', error.message);
    });
  }

  build() {
    Stack() {
      Column() {
        this.header()
        Row() {
          TextInput({ placeholder: '搜索姓名或学号', text: this.searchKeyword })
            .layoutWeight(1)
            .height(40)
            .backgroundColor('#FFFFFF')
            .borderRadius(6)
            .onChange((value: string) => {
              this.searchKeyword = value;
              this.loadUsers();
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })

        if (this.users.length === 0) {
          Column() {
            Text('暂无有效人员')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#182431')
            Text('点击右上角添加人员')
              .fontSize(13)
              .fontColor('#989A9C')
              .margin({ top: 6 })
          }
          .layoutWeight(1)
          .width('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          List() {
      ForEach(this.users, (user: UserModel, index: number) => {
        ListItem() {
          AnimatedCard({ delay: index * 40 }) {
            this.userItem(user)
          }
        }
      }, (user: UserModel) => `${user.id}_${user.updatedAt}`)
          }
          .opacity(this.userListOpacity)
          .translate({ y: this.userListTranslateY })
          .layoutWeight(1)
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 10 })
          .divider({ strokeWidth: 8, color: '#F1F3F5' })
        }

        AppBottomNav({ active: 'users' })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Colors.bg)

      if (this.showFormDialog) {
        this.formDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private header() {
    Row() {
      Column() {
        Text('人员管理')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
        Text(`${this.users.length} 名有效人员`)
          .fontSize(12)
          .fontColor('#989A9C')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Button() {
        Row() {
          Image($r('app.media.icon_add'))
            .width(17)
            .height(17)
            .fillColor('#FFFFFF')
          Text('添加')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .margin({ left: 5 })
        }
      }
      .height(38)
      .padding({ left: 13, right: 13 })
      .type(ButtonType.Normal)
      .borderRadius(6)
      .backgroundColor('#007DFF')
      .onClick(() => this.openAddDialog())
    }
    .width('100%')
    .height(64)
    .padding({ left: 18, right: 18 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })
  }

  @Builder
  private userItem(user: UserModel) {
    Column() {
      Row() {
        Text(user.name.charAt(0))
          .width(42)
          .height(42)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .textAlign(TextAlign.Center)
          .backgroundColor('#007DFF')
          .borderRadius(21)
          .margin({ right: 12 })
        Column() {
          Row() {
            Text(user.name)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#182431')
            Text(user.faceEnrolled ? '已录入人脸' : '未录入人脸')
              .fontSize(10)
              .fontColor(user.faceEnrolled ? '#34C759' : '#FF3B30')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(user.faceEnrolled ? '#EEFAF1' : '#FFF1F0')
              .borderRadius(4)
              .margin({ left: 8 })
          }
          Text(`${user.studentNo} · ${user.className}`)
            .fontSize(12)
            .fontColor('#989A9C')
            .margin({ top: 5 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (!this.compactMode) {
          this.actionButtons(user)
        }
      }
      .width('100%')

      if (this.compactMode) {
        Row() {
          Blank()
          Scroll() {
            this.actionButtons(user)
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(15)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 15, color: '#1A000000', offsetY: 6 })
  }

  @Builder
  private actionButtons(user: UserModel) {
    Row() {
      Button('编辑')
        .height(32)
        .fontSize(12)
        .fontColor('#007DFF')
        .backgroundColor('#EAF4FF')
        .borderRadius(6)
        .onClick(() => this.openEditDialog(user))
      Button(user.faceEnrolled ? '重录' : '录脸')
        .height(32)
        .fontSize(12)
        .fontColor('#34C759')
        .backgroundColor('#EEFAF1')
        .borderRadius(6)
        .margin({ left: 7 })
        .onClick(() => this.openFaceEnroll(user))
      Button('归档')
        .height(32)
        .fontSize(12)
        .fontColor('#FF3B30')
        .backgroundColor('#FFF1F0')
        .borderRadius(6)
        .margin({ left: 7 })
        .onClick(() => this.confirmArchive(user))
    }
  }

  @Builder
  private formDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.36)')
        .onClick(() => { this.showFormDialog = false; })
      Scroll() {
        Column() {
          Text(this.editingUser ? '编辑人员' : '添加人员')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor('#182431')
            .alignSelf(ItemAlign.Start)
            .margin({ bottom: 16 })
          TextInput({ placeholder: '学号', text: this.formStudentNo })
            .width('100%')
            .height(42)
            .onChange((value: string) => { this.formStudentNo = value; })
          TextInput({ placeholder: '姓名', text: this.formName })
            .width('100%')
            .height(42)
            .margin({ top: 10 })
            .onChange((value: string) => { this.formName = value; })

          Text('所属班级')
            .fontSize(13)
            .fontColor('#182431')
            .alignSelf(ItemAlign.Start)
            .margin({ top: 16, bottom: 6 })
          Column() {
            ForEach(this.classes, (item: AdminClass) => {
              Row() {
                Text(item.name)
                  .fontSize(13)
                  .fontColor('#182431')
                  .layoutWeight(1)
                Circle()
                  .width(16)
                  .height(16)
                  .fill(this.formClassId === item.id ? '#007DFF' : '#FFFFFF')
                  .border({ width: 1.5, color: this.formClassId === item.id ? '#007DFF' : '#B8C1CC' })
              }
              .width('100%')
              .padding({ top: 9, bottom: 9 })
              .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })
              .onClick(() => { this.formClassId = item.id; })
            }, (item: AdminClass) => item.id.toString())
          }
          .width('100%')

          Text('选修课程')
            .fontSize(13)
            .fontColor('#182431')
            .alignSelf(ItemAlign.Start)
            .margin({ top: 16, bottom: 6 })
          Column() {
            ForEach(this.courses, (course: Course) => {
              Row() {
                Column() {
                  Text(course.name)
                    .fontSize(13)
                    .fontColor('#182431')
                  Text(course.code)
                    .fontSize(11)
                    .fontColor('#989A9C')
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                Checkbox()
                  .select(this.formCourseIds.indexOf(course.id) >= 0)
                  .onChange(() => this.toggleCourse(course.id))
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
              .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })
            }, (course: Course) => course.id.toString())
          }
          .width('100%')

          Row() {
            Button('取消')
              .layoutWeight(1)
              .height(42)
              .fontColor('#182431')
              .backgroundColor('#F1F3F5')
              .borderRadius(6)
              .margin({ right: 6 })
              .onClick(() => { this.showFormDialog = false; })
            Button('保存')
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#007DFF')
              .borderRadius(6)
              .margin({ left: 6 })
              .onClick(() => this.saveUser())
          }
          .width('100%')
          .margin({ top: 18 })
        }
        .width('100%')
        .padding(22)
      }
      .width(this.compactMode ? '92%' : 460)
      .constraintSize({ maxHeight: '86%' })
      .backgroundColor('#FFFFFF')
      .shadow(Shadows.card)
      .borderRadius(Radius.card)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
  }
}
