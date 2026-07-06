import mediaquery from '@ohos.mediaquery';
import { AppBottomNav } from '../components/AppBottomNav';
import { StatusPill, StatusType } from '../components/StatusPill';
import { AttendanceService } from '../services/AttendanceService';
import { UserService } from '../services/UserService';
import { AttendanceRecord, AttendanceSession, CheckInStatus } from '../models/AttendanceModel';
import { CheckInAttempt, CheckInAttemptStage } from '../models/CheckInAttemptModel';
import { UserModel } from '../models/UserModel';
import { DateUtils } from '../utils/DateUtils';
import { Logger } from '../utils/Logger';
import { AttendanceAbsentRow, ExportService } from '../services/ExportService';
import { Shadows, Radius, Colors } from '../utils/DesignTokens';
import { AnimatedCard } from '../components/AnimatedCard';
import { FaceEnrollButton } from '../components/FaceEnrollButton';

interface SessionMemberSnapshot {
  sessionId: number;
  user: UserModel;
}

@Entry
@Component
struct RecordListPage {
  @State records: AttendanceRecord[] = [];
  @State attempts: CheckInAttempt[] = [];
  @State sessions: AttendanceSession[] = [];
  @State users: UserModel[] = [];
  @State expectedMembers: SessionMemberSnapshot[] = [];
  @State selectedSessionId: number = -1;
  @State selectedClassName: string = '';
  @State searchKeyword: string = '';
  @State dateKeyword: string = '';
  @State expandedMode: boolean = false;
  @State isExporting: boolean = false;
  @State listOpacity: number = 0;
  @State listTranslateY: number = 10;

  private attendanceService: AttendanceService = new AttendanceService();
  private userService: UserService = new UserService();
  private expandedListener?: mediaquery.MediaQueryListener;
  private exportService: ExportService = new ExportService();

  async aboutToAppear(): Promise<void> {
    this.expandedListener = this.getUIContext().getMediaQuery().matchMediaSync('(width >= 840vp)');
    this.expandedMode = this.expandedListener.matches;
    this.expandedListener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.expandedMode = result.matches;
    });
    await this.loadData();
    // 触发列表入场动画
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.listOpacity = 1;
        this.listTranslateY = 0;
      });
    }, 100);
  }

  onPageShow(): void {
    this.loadData();
  }

  aboutToDisappear(): void {
    this.expandedListener?.off('change');
  }

  private async loadData(): Promise<void> {
    try {
      this.sessions = await this.attendanceService.getAllSessions();
      this.users = await this.userService.getAllUsers(true);
      this.records = this.selectedSessionId > 0
        ? await this.attendanceService.getSessionRecords(this.selectedSessionId)
        : await this.attendanceService.getAllRecords();
      const snapshots: SessionMemberSnapshot[] = [];
      const attempts: CheckInAttempt[] = [];
      for (let index = 0; index < this.sessions.length; index++) {
        const session = this.sessions[index];
        const members = await this.attendanceService.getSessionMembers(session.id);
        members.forEach((user: UserModel) => {
          snapshots.push({ sessionId: session.id, user: user });
        });
        if (this.selectedSessionId <= 0 || this.selectedSessionId === session.id) {
          const sessionAttempts = await this.attendanceService.getRecentAttempts(session.id, 80);
          sessionAttempts.forEach((attempt: CheckInAttempt) => {
            attempts.push(attempt);
          });
        }
      }
      this.expectedMembers = snapshots;
      attempts.sort((left: CheckInAttempt, right: CheckInAttempt) => right.attemptTime - left.attemptTime);
      this.attempts = attempts.filter((attempt: CheckInAttempt) => !attempt.success);
    } catch (error) {
      Logger.error('加载考勤记录失败: %{public}s', JSON.stringify(error));
    }
  }

  private getRecordUser(record: AttendanceRecord): UserModel | undefined {
    const snapshot = this.expectedMembers.find((item: SessionMemberSnapshot) =>
      item.sessionId === record.sessionId && item.user.id === record.userId
    );
    return snapshot?.user ?? this.users.find((user: UserModel) => user.id === record.userId);
  }

  private getSession(sessionId: number): AttendanceSession | undefined {
    return this.sessions.find((session: AttendanceSession) => session.id === sessionId);
  }

  private getStatusText(status: CheckInStatus): string {
    if (status === CheckInStatus.NORMAL) return '正常';
    if (status === CheckInStatus.LATE) return '迟到';
    if (status === CheckInStatus.ABSENT) return '缺勤';
    return '失败';
  }

  private getStatusColor(status: CheckInStatus): string {
    if (status === CheckInStatus.NORMAL) return Colors.success;
    if (status === CheckInStatus.LATE) return Colors.warning;
    if (status === CheckInStatus.ABSENT) return Colors.danger;
    return Colors.danger;
  }

  private getAttemptUser(attempt: CheckInAttempt): UserModel | undefined {
    const snapshot = this.expectedMembers.find((item: SessionMemberSnapshot) =>
      item.sessionId === attempt.sessionId && item.user.id === attempt.userId
    );
    return snapshot?.user ?? this.users.find((user: UserModel) => user.id === attempt.userId);
  }

  private hasLocationResult(record: AttendanceRecord): boolean {
    return record.checkLatitude !== 0 || record.checkLongitude !== 0 || record.distanceMeters > 0;
  }

  private getLocationText(record: AttendanceRecord): string {
    if (record.status === CheckInStatus.ABSENT) {
      return '未检测';
    }
    const session = this.getSession(record.sessionId);
    if (!session?.enableLocationCheck && !this.hasLocationResult(record)) {
      return '未启用';
    }
    if (!record.locationPassed) {
      return '失败';
    }
    return record.distanceMeters > 0 ? `${Math.round(record.distanceMeters)}m` : '通过';
  }

  private getLocationDetail(record: AttendanceRecord): string {
    if (record.status === CheckInStatus.ABSENT) {
      return '位置：未检测';
    }
    const session = this.getSession(record.sessionId);
    if (!session?.enableLocationCheck && !this.hasLocationResult(record)) {
      return '位置：未启用';
    }
    if (!record.locationPassed) {
      return `位置失败：${record.locationFailReason || '未通过地理围栏'}`;
    }
    const accuracyText = record.checkLocationAccuracy > 0
      ? `，精度约 ${Math.round(record.checkLocationAccuracy)} 米` : '';
    const distanceText = record.distanceMeters > 0 ? `距签到点约 ${Math.round(record.distanceMeters)} 米` : '已通过';
    return `位置：${distanceText}${accuracyText}`;
  }

  private getLocationColor(record: AttendanceRecord): string {
    if (record.status === CheckInStatus.ABSENT) {
      return Colors.textTertiary;
    }
    if (!record.locationPassed) {
      return Colors.danger;
    }
    if (this.getLocationText(record) === '未启用') {
      return Colors.textTertiary;
    }
    return Colors.success;
  }

  private getAttemptStageText(stage: string): string {
    if (stage === CheckInAttemptStage.LOCATION) return '位置';
    if (stage === CheckInAttemptStage.LIVENESS) return '活体';
    if (stage === CheckInAttemptStage.CAPTURE) return '拍照';
    if (stage === CheckInAttemptStage.FACE) return '人脸';
    return '系统';
  }

  private getAttemptLocationText(attempt: CheckInAttempt): string {
    const session = this.getSession(attempt.sessionId);
    if (!session?.enableLocationCheck) {
      return '未启用';
    }
    if (attempt.distanceMeters > 0) {
      return `${Math.round(attempt.distanceMeters)}m`;
    }
    return attempt.locationPassed ? '通过' : '失败';
  }

  private getAttemptLocationColor(attempt: CheckInAttempt): string {
    if (this.getAttemptLocationText(attempt) === '未启用') {
      return Colors.textTertiary;
    }
    return attempt.locationPassed ? Colors.success : Colors.danger;
  }

  private getFilteredAttempts(): CheckInAttempt[] {
    const keyword = this.searchKeyword.trim().toLowerCase();
    const date = this.dateKeyword.trim();
    return this.attempts.filter((attempt: CheckInAttempt) => {
      const user = this.getAttemptUser(attempt);
      const matchesKeyword = keyword === '' ||
        user?.name.toLowerCase().includes(keyword) ||
        user?.studentNo.toLowerCase().includes(keyword);
      const matchesClass = this.selectedClassName === '' || user?.className === this.selectedClassName;
      const matchesDate = date === '' || DateUtils.formatDate(attempt.attemptTime).includes(date);
      return matchesKeyword && matchesClass && matchesDate;
    });
  }

  private getFilteredRecords(): AttendanceRecord[] {
    const keyword = this.searchKeyword.trim().toLowerCase();
    const date = this.dateKeyword.trim();
    return this.records.filter((record: AttendanceRecord) => {
      const user = this.getRecordUser(record);
      const matchesKeyword = keyword === '' ||
        user?.name.toLowerCase().includes(keyword) ||
        user?.studentNo.toLowerCase().includes(keyword);
      const matchesClass = this.selectedClassName === '' || user?.className === this.selectedClassName;
      const matchesDate = date === '' || DateUtils.formatDate(record.checkInTime).includes(date);
      return matchesKeyword && matchesClass && matchesDate;
    });
  }

  private getClassNames(): string[] {
    const names: string[] = [];
    this.expectedMembers.forEach((item: SessionMemberSnapshot) => {
      const className = item.user.className.trim();
      if (className !== '' && !names.includes(className)) {
        names.push(className);
      }
    });
    this.users.forEach((user: UserModel) => {
      const className = user.className.trim();
      if (className !== '' && !names.includes(className)) {
        names.push(className);
      }
    });
    return names.sort();
  }

  private getNormalCount(): number {
    return this.getFilteredRecords().filter((record: AttendanceRecord) =>
      record.status === CheckInStatus.NORMAL
    ).length;
  }

  private getLateCount(): number {
    return this.getFilteredRecords().filter((record: AttendanceRecord) =>
      record.status === CheckInStatus.LATE
    ).length;
  }

  private getAbsentCount(): number {
    return this.getFilteredRecords().filter((record: AttendanceRecord) =>
      record.status === CheckInStatus.ABSENT
    ).length;
  }

  /**
   * 从已结束场次的 ABSENT 记录中提取缺勤行，供 CSV 导出使用。
   * 缺勤记录由 endSession() 在结束场次时自动生成。
   */
  private getFilteredAbsentRows(): AttendanceAbsentRow[] {
    return this.getFilteredRecords()
      .filter((record: AttendanceRecord) => record.status === CheckInStatus.ABSENT)
      .map((record: AttendanceRecord) => {
        const user = this.getRecordUser(record);
        return {
          sessionId: record.sessionId,
          userName: user?.name ?? '历史用户',
          studentNo: user?.studentNo ?? '',
          className: user?.className ?? ''
        } as AttendanceAbsentRow;
      });
  }

  private getReportRowCount(): number {
    return this.getFilteredRecords().length + this.getFilteredAttempts().length;
  }

  private async exportRecords(): Promise<void> {
    if (this.isExporting || this.getReportRowCount() === 0) {
      return;
    }
    const context = this.getUIContext().getHostContext();
    if (!context) {
      this.getUIContext().getPromptAction().showToast({
        message: '无法获取文件保存上下文',
        duration: 2200
      });
      return;
    }
    this.isExporting = true;
    try {
      const session = this.selectedSessionId > 0
        ? this.sessions.find((s: AttendanceSession) => s.id === this.selectedSessionId)
        : undefined;
      const prefix = session ? session.title : '';
      await this.exportService.exportAttendanceCsv(
        context,
        this.getFilteredRecords(),
        this.sessions,
        this.users,
        this.getFilteredAbsentRows(),
        this.getFilteredAttempts(),
        prefix
      );
      this.getUIContext().getPromptAction().showToast({
        message: 'CSV 报表已导出',
        duration: 2200
      });
    } catch (error) {
      Logger.warn('导出考勤报表未完成: %{public}s', JSON.stringify(error));
    } finally {
      this.isExporting = false;
    }
  }

  build() {
    Column() {
      this.header()
      this.filterBar()
      this.classSelector()
      this.sessionSelector()
      this.summaryBar()

      if (this.getFilteredRecords().length === 0 && this.getFilteredAttempts().length === 0) {
        Column() {
          Text('暂无符合条件的考勤记录')
            .fontSize(15)
            .fontColor(Colors.textTertiary)
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.expandedMode) {
        this.reportTable()
      } else {
        this.recordList()
      }

      AppBottomNav({ active: 'records' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.bg)
  }

  @Builder
  private classSelector() {
    Scroll() {
      Row() {
        Text('全部班级')
          .fontSize(12)
          .fontColor(this.selectedClassName === '' ? Colors.card : Colors.textPrimary)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.selectedClassName === '' ? Colors.primary : Colors.card)
          .borderRadius(Radius.button)
          .margin({ right: 7 })
          .onClick(() => {
            this.selectedClassName = '';
          })
        ForEach(this.getClassNames(), (className: string) => {
          Text(className)
            .fontSize(12)
            .fontColor(this.selectedClassName === className ? Colors.card : Colors.textPrimary)
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor(this.selectedClassName === className ? Colors.primary : Colors.card)
            .borderRadius(Radius.button)
            .margin({ right: 7 })
            .maxLines(1)
            .onClick(() => {
              this.selectedClassName = className;
            })
        }, (className: string) => className)
      }
      .padding({ left: 14, right: 14, bottom: 8 })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  private header() {
    Row() {
      Column() {
        Text('考勤记录')
          .fontSize(21)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
        Text('按场次查看签到结果与人脸匹配度')
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      FaceEnrollButton({ animationEnabled: !this.isExporting && this.getReportRowCount() > 0 }) {
        Button(this.isExporting ? '导出中' : '导出 CSV')
          .height(36)
          .fontSize(12)
          .fontColor(Colors.primary)
          .backgroundColor(Colors.primaryBg)
          .borderRadius(6)
          .enabled(!this.isExporting && this.getReportRowCount() > 0)
          .onClick(() => this.exportRecords())
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 18, right: 18 })
    .backgroundColor(Colors.card)
    .border({ width: { bottom: 0.5 }, color: Colors.border })
  }

  @Builder
  private filterBar() {
    Row() {
      TextInput({ placeholder: '搜索姓名或学号', text: this.searchKeyword })
        .layoutWeight(1)
        .height(38)
        .backgroundColor(Colors.card)
        .borderRadius(6)
        .onChange((value: string) => { this.searchKeyword = value; })
      TextInput({ placeholder: '日期 YYYY-MM-DD', text: this.dateKeyword })
        .width(this.expandedMode ? 190 : '42%')
        .height(38)
        .backgroundColor(Colors.card)
        .borderRadius(6)
        .margin({ left: 8 })
        .enterKeyType(EnterKeyType.Search)
        .onSubmit((_enterKey: EnterKeyType) => {
          this.dateKeyword = this.dateKeyword.trim();
        })
        .onChange((value: string) => { this.dateKeyword = value; })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 8 })
  }

  @Builder
  private sessionSelector() {
    Scroll() {
      Row() {
        Text('全部场次')
          .fontSize(12)
          .fontColor(this.selectedSessionId <= 0 ? Colors.card : Colors.textPrimary)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.selectedSessionId <= 0 ? Colors.primary : Colors.card)
          .borderRadius(6)
          .margin({ right: 7 })
          .onClick(() => {
            this.selectedSessionId = -1;
            this.loadData();
          })
        ForEach(this.sessions, (session: AttendanceSession) => {
          Text(`${session.courseName} · ${DateUtils.formatDate(session.startTime)}`)
            .fontSize(12)
            .fontColor(this.selectedSessionId === session.id ? Colors.card : Colors.textPrimary)
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor(this.selectedSessionId === session.id ? Colors.primary : Colors.card)
            .borderRadius(6)
            .margin({ right: 7 })
            .maxLines(1)
            .onClick(() => {
              this.selectedSessionId = session.id;
              this.loadData();
            })
        }, (session: AttendanceSession) => session.id.toString())
      }
      .padding({ left: 14, right: 14, bottom: 9 })
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  private summaryBar() {
    Row() {
      this.summaryCell('记录', () => this.getFilteredRecords().length, Colors.primary)
      this.summaryCell('正常', () => this.getNormalCount(), Colors.success)
      this.summaryCell('迟到', () => this.getLateCount(), Colors.warning)
      this.summaryCell('缺勤', () => this.getAbsentCount(), Colors.danger)
      this.summaryCell('失败尝试', () => this.getFilteredAttempts().length, Colors.danger)
    }
    .width('100%')
    .height(60)
    .margin({ left: 14, right: 14, bottom: 9 })
    .backgroundColor(Colors.card)
    .borderRadius(8)
  }

  @Builder
  private summaryCell(label: string, value: () => number, color: string) {
    Row() {
      Text(value().toString())
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(Colors.textTertiary)
        .margin({ left: 5 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private recordList() {
    List() {
      ForEach(this.getFilteredRecords(), (record: AttendanceRecord, index: number) => {
        ListItem() {
          AnimatedCard({ delay: Math.min(index, 8) * 35 }) {
            Column() {
            Row() {
              Circle()
                .width(8)
                .height(8)
                .fill(this.getStatusColor(record.status))
                .margin({ right: 10 })
                Column() {
                  Text(this.getRecordUser(record)?.name ?? '历史用户')
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Colors.textPrimary)
                  Text(`${this.getRecordUser(record)?.studentNo ?? ''} · ${this.getRecordUser(record)?.className ?? ''}`)
                    .fontSize(11)
                    .fontColor(Colors.textTertiary)
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                StatusPill({
                  status: record.status === CheckInStatus.NORMAL ? StatusType.NORMAL :
                          record.status === CheckInStatus.LATE ? StatusType.LATE :
                          record.status === CheckInStatus.ABSENT ? StatusType.ABSENT : StatusType.FAILED,
                  text: record.status === CheckInStatus.NORMAL ? '正常' :
                        record.status === CheckInStatus.LATE ? '迟到' :
                        record.status === CheckInStatus.ABSENT ? '缺勤' : '失败'
                })
              }
              Row() {
                Text(this.getSession(record.sessionId)?.courseName ?? '历史课程')
                  .fontSize(12)
                  .fontColor(Colors.primary)
                  .layoutWeight(1)
                if (record.status === CheckInStatus.ABSENT) {
                  Text('未签到')
                    .fontSize(11)
                    .fontColor(Colors.textTertiary)
                  Text('—')
                    .fontSize(12)
                    .fontColor(Colors.textTertiary)
                    .margin({ left: 10 })
                } else {
                  Text(`${DateUtils.formatDate(record.checkInTime)} ${DateUtils.formatTime(record.checkInTime)}`)
                    .fontSize(11)
                    .fontColor(Colors.textTertiary)
                  Text(`${(record.compareScore * 100).toFixed(0)}%`)
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(Colors.textPrimary)
                    .margin({ left: 10 })
                }
              }
              .width('100%')
              .margin({ top: 11 })
              Text(this.getLocationDetail(record))
                .fontSize(11)
                .fontColor(this.getLocationColor(record))
                .maxLines(2)
                .margin({ top: 7 })
                .alignSelf(ItemAlign.Start)
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Colors.card)
            .borderRadius(Radius.card)
            .shadow(Shadows.card)
          }
        }
      }, (record: AttendanceRecord) => record.id.toString())
      if (this.getFilteredAttempts().length > 0) {
        ListItem() {
          Text('失败尝试')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.dangerDark)
            .padding({ left: 2, top: 6, bottom: 2 })
        }
        ForEach(this.getFilteredAttempts(), (attempt: CheckInAttempt, index: number) => {
          ListItem() {
            AnimatedCard({ delay: Math.min(index, 8) * 35 }) {
              Column() {
                Row() {
                  Circle()
                    .width(8)
                    .height(8)
                    .fill(Colors.danger)
                    .margin({ right: 10 })
                  Column() {
                    Text(this.getAttemptUser(attempt)?.name ?? '历史用户')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Colors.textPrimary)
                    Text(`${this.getAttemptUser(attempt)?.studentNo ?? ''} · ${this.getAttemptUser(attempt)?.className ?? ''}`)
                      .fontSize(11)
                      .fontColor(Colors.textTertiary)
                      .margin({ top: 3 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  StatusPill({
                    status: StatusType.FAILED,
                    text: `${this.getAttemptStageText(attempt.stage)}失败`
                  })
                }
                Row() {
                  Text(this.getSession(attempt.sessionId)?.courseName ?? '历史课程')
                    .fontSize(12)
                    .fontColor(Colors.primary)
                    .layoutWeight(1)
                  Text(`${DateUtils.formatDate(attempt.attemptTime)} ${DateUtils.formatTime(attempt.attemptTime)}`)
                    .fontSize(11)
                    .fontColor(Colors.textTertiary)
                }
                .width('100%')
                .margin({ top: 11 })
                Text(attempt.failReason)
                  .fontSize(11)
                  .fontColor(Colors.dangerDark)
                  .maxLines(2)
                  .margin({ top: 7 })
                  .alignSelf(ItemAlign.Start)
                Text(`位置：${this.getAttemptLocationText(attempt)}`)
                  .fontSize(11)
                  .fontColor(this.getAttemptLocationColor(attempt))
                  .margin({ top: 5 })
                  .alignSelf(ItemAlign.Start)
              }
              .width('100%')
              .padding(14)
              .backgroundColor(Colors.card)
              .borderRadius(Radius.card)
              .shadow(Shadows.card)
            }
          }
        }, (attempt: CheckInAttempt) => `attempt-${attempt.id}`)
      }
    }
    .opacity(this.listOpacity)
    .translate({ y: this.listTranslateY })
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 14, right: 14, bottom: 8 })
    .divider({ strokeWidth: 8, color: Colors.borderLight })
  }

  @Builder
  private reportTable() {
    Column() {
      Row() {
        this.tableHeader('人员', 2)
        this.tableHeader('班级', 2)
        this.tableHeader('课程 / 场次', 3)
        this.tableHeader('签到时间', 2)
        this.tableHeader('匹配度', 1)
        this.tableHeader('位置', 1)
        this.tableHeader('状态', 1)
      }
      .width('100%')
      .height(42)
      .padding({ left: 14, right: 14 })
      .backgroundColor(Colors.bg)
      List() {
        ForEach(this.getFilteredRecords(), (record: AttendanceRecord, index: number) => {
          ListItem() {
            AnimatedCard({ delay: Math.min(index, 8) * 30 }) {
              Row() {
              this.tableText(
                `${this.getRecordUser(record)?.name ?? '历史用户'}\n${this.getRecordUser(record)?.studentNo ?? ''}`,
                2,
                Colors.textPrimary
              )
              this.tableText(this.getRecordUser(record)?.className ?? '', 2, Colors.textPrimary)
              this.tableText(
                `${this.getSession(record.sessionId)?.courseName ?? '历史课程'}\n${this.getSession(record.sessionId)?.title ?? ''}`,
                3,
                Colors.textPrimary
              )
              if (record.status === CheckInStatus.ABSENT) {
                this.tableText('未签到', 2, Colors.textTertiary)
                this.tableText('—', 1, Colors.textTertiary)
                this.tableText('未检测', 1, Colors.textTertiary)
              } else {
                this.tableText(
                  `${DateUtils.formatDate(record.checkInTime)}\n${DateUtils.formatTime(record.checkInTime)}`,
                  2,
                  Colors.textTertiary
                )
                this.tableText(`${(record.compareScore * 100).toFixed(0)}%`, 1, Colors.primary)
                this.tableText(this.getLocationText(record), 1, this.getLocationColor(record))
              }
              StatusPill({
                status: record.status === CheckInStatus.NORMAL ? StatusType.NORMAL :
                        record.status === CheckInStatus.LATE ? StatusType.LATE :
                        record.status === CheckInStatus.ABSENT ? StatusType.ABSENT : StatusType.FAILED,
                text: record.status === CheckInStatus.NORMAL ? '正常' :
                      record.status === CheckInStatus.LATE ? '迟到' :
                      record.status === CheckInStatus.ABSENT ? '缺勤' : '失败'
              })
            }
            .width('100%')
            .constraintSize({ minHeight: 58 })
            .padding({ left: 14, right: 14, top: 9, bottom: 9 })
              .backgroundColor(Colors.card)
            }
          }
        }, (record: AttendanceRecord) => record.id.toString())
        ForEach(this.getFilteredAttempts(), (attempt: CheckInAttempt, index: number) => {
          ListItem() {
            AnimatedCard({ delay: Math.min(index, 8) * 30 }) {
              Row() {
                this.tableText(
                  `${this.getAttemptUser(attempt)?.name ?? '历史用户'}\n${this.getAttemptUser(attempt)?.studentNo ?? ''}`,
                  2,
                  Colors.textPrimary
                )
                this.tableText(this.getAttemptUser(attempt)?.className ?? '', 2, Colors.textPrimary)
                this.tableText(
                  `${this.getSession(attempt.sessionId)?.courseName ?? '历史课程'}\n${attempt.failReason}`,
                  3,
                  Colors.dangerDark
                )
                this.tableText(
                  `${DateUtils.formatDate(attempt.attemptTime)}\n${DateUtils.formatTime(attempt.attemptTime)}`,
                  2,
                  Colors.textTertiary
                )
                this.tableText(attempt.compareScore > 0 ? `${(attempt.compareScore * 100).toFixed(0)}%` : '—', 1, Colors.textTertiary)
                this.tableText(this.getAttemptLocationText(attempt), 1, this.getAttemptLocationColor(attempt))
                StatusPill({
                  status: StatusType.FAILED,
                  text: `${this.getAttemptStageText(attempt.stage)}失败`
                })
              }
              .width('100%')
              .constraintSize({ minHeight: 58 })
              .padding({ left: 14, right: 14, top: 9, bottom: 9 })
              .backgroundColor(Colors.card)
            }
          }
        }, (attempt: CheckInAttempt) => `attempt-${attempt.id}`)
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0.5, color: Colors.border })
    }
    .layoutWeight(1)
    .width('100%')
    .margin({ left: 14, right: 14, bottom: 10 })
    .borderRadius(8)
  }

  @Builder
  private tableHeader(text: string, weight: number) {
    Text(text)
      .layoutWeight(weight)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(Colors.textTertiary)
      .width('100%')
      .textAlign(TextAlign.Center)
      .height('100%')
      .align(Alignment.Center)
  }

  @Builder
  private tableText(text: string, weight: number, color: string) {
    Text(text)
      .layoutWeight(weight)
      .fontSize(12)
      .fontColor(color)
      .maxLines(2)
  }
}
