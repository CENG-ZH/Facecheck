import mediaquery from '@ohos.mediaquery';
import { AppBottomNav } from '../components/AppBottomNav';
import { StatusPill, StatusType } from '../components/StatusPill';
import { AttendanceService } from '../services/AttendanceService';
import { UserService } from '../services/UserService';
import { AttendanceRecord, AttendanceSession, CheckInStatus } from '../models/AttendanceModel';
import { UserModel } from '../models/UserModel';
import { DateUtils } from '../utils/DateUtils';
import { Logger } from '../utils/Logger';
import { AttendanceAbsentRow, ExportService } from '../services/ExportService';
import { Shadows, Radius, Colors } from '../utils/DesignTokens';
import { AnimatedCard } from '../components/AnimatedCard';

interface SessionMemberSnapshot {
  sessionId: number;
  user: UserModel;
}

@Entry
@Component
struct RecordListPage {
  @State records: AttendanceRecord[] = [];
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
      for (let index = 0; index < this.sessions.length; index++) {
        const session = this.sessions[index];
        const members = await this.attendanceService.getSessionMembers(session.id);
        members.forEach((user: UserModel) => {
          snapshots.push({ sessionId: session.id, user: user });
        });
      }
      this.expectedMembers = snapshots;
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
    return '失败';
  }

  private getStatusColor(status: CheckInStatus): string {
    if (status === CheckInStatus.NORMAL) return '#34C759';
    if (status === CheckInStatus.LATE) return '#F59E0B';
    return '#FF3B30';
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
    return this.getFilteredAbsentRows().length;
  }

  private getFilteredAbsentRows(): AttendanceAbsentRow[] {
    const keyword = this.searchKeyword.trim().toLowerCase();
    const date = this.dateKeyword.trim();
    const absentRows: AttendanceAbsentRow[] = [];
    this.expectedMembers.forEach((item: SessionMemberSnapshot) => {
      if (this.selectedSessionId > 0 && item.sessionId !== this.selectedSessionId) {
        return;
      }
      const session = this.getSession(item.sessionId);
      if (date !== '' && (!session || !DateUtils.formatDate(session.startTime).includes(date))) {
        return;
      }
      const matchesKeyword = keyword === '' ||
        item.user.name.toLowerCase().includes(keyword) ||
        item.user.studentNo.toLowerCase().includes(keyword);
      const matchesClass = this.selectedClassName === '' ||
        item.user.className === this.selectedClassName;
      if (!matchesKeyword || !matchesClass) {
        return;
      }
      const hasCheckedIn = this.records.some((record: AttendanceRecord) =>
        record.sessionId === item.sessionId && record.userId === item.user.id
      );
      if (!hasCheckedIn) {
        absentRows.push({
          sessionId: item.sessionId,
          userName: item.user.name,
          studentNo: item.user.studentNo,
          className: item.user.className
        });
      }
    });
    return absentRows;
  }

  private getReportRowCount(): number {
    return this.getFilteredRecords().length + this.getFilteredAbsentRows().length;
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
      await this.exportService.exportAttendanceCsv(
        context,
        this.getFilteredRecords(),
        this.sessions,
        this.users,
        this.getFilteredAbsentRows()
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

      if (this.getFilteredRecords().length === 0) {
        Column() {
          Text('暂无符合条件的考勤记录')
            .fontSize(15)
            .fontColor('#989A9C')
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
          .fontColor('#182431')
        Text('按场次查看签到结果与人脸匹配度')
          .fontSize(12)
          .fontColor('#989A9C')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      Button(this.isExporting ? '导出中' : '导出 CSV')
        .height(36)
        .fontSize(12)
        .fontColor('#007DFF')
        .backgroundColor('#EAF4FF')
        .borderRadius(6)
        .enabled(!this.isExporting && this.getReportRowCount() > 0)
        .onClick(() => this.exportRecords())
    }
    .width('100%')
    .height(64)
    .padding({ left: 18, right: 18 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 0.5 }, color: '#E5E5E5' })
  }

  @Builder
  private filterBar() {
    Row() {
      TextInput({ placeholder: '搜索姓名或学号', text: this.searchKeyword })
        .layoutWeight(1)
        .height(38)
        .backgroundColor('#FFFFFF')
        .borderRadius(6)
        .onChange((value: string) => { this.searchKeyword = value; })
      TextInput({ placeholder: '日期 YYYY-MM-DD', text: this.dateKeyword })
        .width(this.expandedMode ? 190 : '42%')
        .height(38)
        .backgroundColor('#FFFFFF')
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
          .fontColor(this.selectedSessionId <= 0 ? '#FFFFFF' : '#182431')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .backgroundColor(this.selectedSessionId <= 0 ? '#007DFF' : '#FFFFFF')
          .borderRadius(6)
          .margin({ right: 7 })
          .onClick(() => {
            this.selectedSessionId = -1;
            this.loadData();
          })
        ForEach(this.sessions, (session: AttendanceSession) => {
          Text(`${session.courseName} · ${DateUtils.formatDate(session.startTime)}`)
            .fontSize(12)
            .fontColor(this.selectedSessionId === session.id ? '#FFFFFF' : '#182431')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .backgroundColor(this.selectedSessionId === session.id ? '#007DFF' : '#FFFFFF')
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
      this.summaryCell('记录', () => this.getFilteredRecords().length, '#007DFF')
      this.summaryCell('正常', () => this.getNormalCount(), '#34C759')
      this.summaryCell('迟到', () => this.getLateCount(), '#F59E0B')
      this.summaryCell('缺勤', () => this.getAbsentCount(), '#FF3B30')
    }
    .width('100%')
    .height(58)
    .margin({ left: 14, right: 14, bottom: 9 })
    .backgroundColor('#FFFFFF')
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
        .fontColor('#989A9C')
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
                    .fontColor('#182431')
                  Text(`${this.getRecordUser(record)?.studentNo ?? ''} · ${this.getRecordUser(record)?.className ?? ''}`)
                    .fontSize(11)
                    .fontColor('#989A9C')
                    .margin({ top: 3 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
                StatusPill({
                  status: record.status === CheckInStatus.NORMAL ? StatusType.NORMAL :
                          record.status === CheckInStatus.LATE ? StatusType.LATE : StatusType.FAILED,
                  text: record.status === CheckInStatus.NORMAL ? '正常' :
                        record.status === CheckInStatus.LATE ? '迟到' : '失败'
                })
              }
              Row() {
                Text(this.getSession(record.sessionId)?.courseName ?? '历史课程')
                  .fontSize(12)
                  .fontColor('#007DFF')
                  .layoutWeight(1)
                Text(`${DateUtils.formatDate(record.checkInTime)} ${DateUtils.formatTime(record.checkInTime)}`)
                  .fontSize(11)
                  .fontColor('#989A9C')
                Text(`${(record.compareScore * 100).toFixed(0)}%`)
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#182431')
                  .margin({ left: 10 })
              }
              .width('100%')
              .margin({ top: 11 })
            }
            .width('100%')
            .padding(14)
            .backgroundColor(Colors.card)
            .borderRadius(Radius.card)
            .shadow(Shadows.card)
          }
        }
      }, (record: AttendanceRecord) => record.id.toString())
    }
    .opacity(this.listOpacity)
    .translate({ y: this.listTranslateY })
    .layoutWeight(1)
    .width('100%')
    .padding({ left: 14, right: 14, bottom: 8 })
    .divider({ strokeWidth: 8, color: '#F1F3F5' })
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
        this.tableHeader('状态', 1)
      }
      .width('100%')
      .height(42)
      .padding({ left: 14, right: 14 })
      .backgroundColor('#F7F8FA')
      List() {
        ForEach(this.getFilteredRecords(), (record: AttendanceRecord, index: number) => {
          ListItem() {
            AnimatedCard({ delay: Math.min(index, 8) * 30 }) {
              Row() {
              this.tableText(
                `${this.getRecordUser(record)?.name ?? '历史用户'}\n${this.getRecordUser(record)?.studentNo ?? ''}`,
                2,
                '#182431'
              )
              this.tableText(this.getRecordUser(record)?.className ?? '', 2, '#182431')
              this.tableText(
                `${this.getSession(record.sessionId)?.courseName ?? '历史课程'}\n${this.getSession(record.sessionId)?.title ?? ''}`,
                3,
                '#182431'
              )
              this.tableText(
                `${DateUtils.formatDate(record.checkInTime)}\n${DateUtils.formatTime(record.checkInTime)}`,
                2,
                '#989A9C'
              )
              this.tableText(`${(record.compareScore * 100).toFixed(0)}%`, 1, '#007DFF')
              StatusPill({
                status: record.status === CheckInStatus.NORMAL ? StatusType.NORMAL :
                        record.status === CheckInStatus.LATE ? StatusType.LATE : StatusType.FAILED,
                text: record.status === CheckInStatus.NORMAL ? '正常' :
                      record.status === CheckInStatus.LATE ? '迟到' : '失败'
              })
            }
            .width('100%')
            .constraintSize({ minHeight: 58 })
            .padding({ left: 14, right: 14, top: 9, bottom: 9 })
              .backgroundColor(Colors.card)
            }
          }
        }, (record: AttendanceRecord) => record.id.toString())
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0.5, color: '#E5E5E5' })
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
      .fontColor('#989A9C')
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
