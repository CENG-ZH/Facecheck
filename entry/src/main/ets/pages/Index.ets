import mediaquery from '@ohos.mediaquery';
import { image } from '@kit.ImageKit';
import { AppBottomNav } from '../components/AppBottomNav';
import { AnimatedCard } from '../components/AnimatedCard';
import { CircleProgress } from '../components/CircleProgress';
import { LocationStatusCard } from '../components/LocationStatusCard';
import { StatusPill, StatusType } from '../components/StatusPill';
import { AttendanceService } from '../services/AttendanceService';
import { UserService } from '../services/UserService';
import { OrganizationService } from '../services/OrganizationService';
import { SettingsService } from '../services/SettingsService';
import { GeoFenceService } from '../services/GeoFenceService';
import { FaceVisionAdapter } from '../kits/FaceVisionAdapter';
import { CameraAdapter } from '../kits/CameraAdapter';
import { LivenessAdapter } from '../kits/LivenessAdapter';
import { LocationAdapter } from '../kits/LocationAdapter';
import {
  AttendanceSession,
  AttendanceStats,
  AttendanceRecord,
  CheckInStatus
} from '../models/AttendanceModel';
import { UserModel } from '../models/UserModel';
import { Course } from '../models/OrganizationModel';
import { CheckInAttempt, CheckInAttemptStage } from '../models/CheckInAttemptModel';
import { GeoFenceConfig, LocationCheckResult } from '../models/LocationModel';
import { DateUtils } from '../utils/DateUtils';
import { Logger } from '../utils/Logger';
import { Shadows, Radius, Colors } from '../utils/DesignTokens';
import { FaceEnrollButton } from '../components/FaceEnrollButton';

interface CheckInActivity {
  id: string;
  userName: string;
  time: number;
  status: CheckInStatus;
  statusText: string;
  message: string;
  score: number;
}

@Entry
@Component
struct HomePage {
  @State currentSession: AttendanceSession | null = null;
  @State stats: AttendanceStats = { totalUsers: 0, checkedIn: 0, lateCount: 0, absentCount: 0 };
  @State attendanceRate: number = 0;
  @State recentRecords: AttendanceRecord[] = [];
  @State recentAttempts: CheckInAttempt[] = [];
  @State allUsers: UserModel[] = [];
  @State filteredUsers: UserModel[] = [];
  @State courses: Course[] = [];
  @State selectedCourseId: number = 0;
  @State selectedUserId: number = -1;
  @State selectedUserName: string = '';
  @State searchKeyword: string = '';
  @State isChecking: boolean = false;
  @State showResult: boolean = false;
  @State checkResultSuccess: boolean = false;
  @State checkResultMessage: string = '';
  @State lastScore: number = 0;
  @State currentStep: number = -1;
  @State stepText: string = '';
  @State showCreateSession: boolean = false;
  @State newSessionTitle: string = '';
  @State compactMode: boolean = false;
  @State expandedMode: boolean = false;
  @State checkInActivities: CheckInActivity[] = [];
  @State displayScore: number = 0;
  @State recentPanelOpacity: number = 0;
  @State resultOpacity: number = 0;
  @State sessionLocationEnabled: boolean = false;
  @State sessionLocationName: string = '当前教室';
  @State sessionRadiusMeters: number = 100;
  @State sessionLatitude: number = 0;
  @State sessionLongitude: number = 0;
  @State sessionLocationAccuracy: number = 0;
  @State sessionLocationMessage: string = '';
  @State isLocatingSessionPoint: boolean = false;
  @State currentLocationMessage: string = '';

  private attendanceService: AttendanceService = new AttendanceService();
  private userService: UserService = new UserService();
  private organizationService: OrganizationService = new OrganizationService();
  private awaitingLivenessResult: boolean = false;
  private compactListener?: mediaquery.MediaQueryListener;
  private expandedListener?: mediaquery.MediaQueryListener;
  private activitySessionId: number = -1;
  private activeAttemptRecorded: boolean = false;
  private activitySequence: number = 0;
  private pendingLocationCheck: LocationCheckResult | null = null;
  private readonly radiusOptions: number[] = [50, 100, 200, 300];

  aboutToAppear(): void {
    this.compactListener = this.getUIContext().getMediaQuery().matchMediaSync('(width < 600vp)');
    this.expandedListener = this.getUIContext().getMediaQuery().matchMediaSync('(width >= 840vp)');
    this.compactMode = this.compactListener.matches;
    this.expandedMode = this.expandedListener.matches;
    this.compactListener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.compactMode = result.matches;
    });
    this.expandedListener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.expandedMode = result.matches;
    });
    // 触发 recentPanel 淡入动画
    setTimeout(() => {
      this.getUIContext().animateTo({ duration: 400, curve: Curve.EaseOut }, () => {
        this.recentPanelOpacity = 1;
      });
    }, 100);
  }

  aboutToDisappear(): void {
    this.compactListener?.off('change');
    this.expandedListener?.off('change');
    FaceVisionAdapter.releaseAll();
  }

  onPageShow(): void {
    this.restorePageState().catch((error: Error) => {
      Logger.error('首页恢复失败: %{public}s', error.message);
      if (this.awaitingLivenessResult) {
        this.awaitingLivenessResult = false;
        this.finishCheckInFailure('恢复签到流程失败，请重试');
      }
    });
  }

  private async restorePageState(): Promise<void> {
    await FaceVisionAdapter.initAll();
    await this.loadData();
    if (this.awaitingLivenessResult) {
      this.awaitingLivenessResult = false;
      await this.resumeAfterLiveness();
    }
  }

  private showToast(message: string, duration: number = 2200): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: duration });
  }

  private async loadData(): Promise<void> {
    try {
      this.currentSession = await this.attendanceService.getActiveSession();
      this.courses = await this.organizationService.getCourses();
      if (this.selectedCourseId <= 0 && this.courses.length > 0) {
        this.selectedCourseId = this.courses[0].id;
      }

      if (this.currentSession) {
        this.allUsers = await this.attendanceService.getSessionMembers(this.currentSession.id);
        this.stats = this.normalizeStats(await this.attendanceService.getSessionStats(this.currentSession.id));
        this.recentRecords = await this.attendanceService.getSessionRecords(this.currentSession.id);
        this.recentAttempts = await this.attendanceService.getRecentAttempts(this.currentSession.id, 30);
      } else {
        this.allUsers = await this.userService.getAllUsers();
        const userStats = await this.userService.getUserStats();
        this.stats = this.normalizeStats({
          totalUsers: userStats.total,
          checkedIn: 0,
          lateCount: 0,
          absentCount: userStats.total
        });
        this.recentRecords = [];
        this.recentAttempts = [];
      }
      this.attendanceRate = this.calculateAttendanceRate(this.stats);
      this.filterUsers();
      this.syncActivityFeed();
    } catch (error) {
      Logger.error('加载首页数据失败: %{public}s', JSON.stringify(error));
    }
  }

  private normalizeStats(stats: AttendanceStats): AttendanceStats {
    const totalUsers = stats.totalUsers > 0 ? Math.floor(stats.totalUsers) : 0;
    const checkedInRaw = stats.checkedIn > 0 ? Math.floor(stats.checkedIn) : 0;
    const checkedIn = Math.min(checkedInRaw, totalUsers);
    const lateCountRaw = stats.lateCount > 0 ? Math.floor(stats.lateCount) : 0;
    const lateCount = Math.min(lateCountRaw, checkedIn);
    const absentCount = Math.max(0, totalUsers - checkedIn);
    return {
      totalUsers: totalUsers,
      checkedIn: checkedIn,
      lateCount: lateCount,
      absentCount: absentCount
    };
  }

  private calculateAttendanceRate(stats: AttendanceStats): number {
    if (!(stats.totalUsers > 0) || !(stats.checkedIn > 0)) {
      return 0;
    }
    return Math.min(stats.checkedIn / stats.totalUsers, 1);
  }

  private filterUsers(): void {
    const keyword = this.searchKeyword.trim().toLowerCase();
    if (keyword === '') {
      this.filteredUsers = this.allUsers;
      return;
    }
    this.filteredUsers = this.allUsers.filter((user: UserModel) =>
      user.studentNo.toLowerCase().includes(keyword) ||
      user.name.toLowerCase().includes(keyword)
    );
  }

  private getUserNameById(userId: number): string {
    return this.allUsers.find((user: UserModel) => user.id === userId)?.name ?? '历史用户';
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

  private syncActivityFeed(): void {
    const sessionId = this.currentSession?.id ?? -1;
    this.activitySessionId = sessionId;
    const recordActivities: CheckInActivity[] = this.recentRecords.slice(0, 20).map((record: AttendanceRecord) => {
      const activity: CheckInActivity = {
        id: `record-${record.id}`,
        userName: this.getUserNameById(record.userId),
        time: record.checkInTime,
        status: record.status,
        statusText: this.getStatusText(record.status),
        message: record.status === CheckInStatus.LATE ? '签到成功，状态为迟到' : '人脸验证通过',
        score: record.compareScore
      };
      return activity;
    });
    const attemptActivities: CheckInActivity[] = this.recentAttempts
      .filter((attempt: CheckInAttempt) => !attempt.success)
      .slice(0, 20)
      .map((attempt: CheckInAttempt) => {
        const activity: CheckInActivity = {
          id: `attempt-db-${attempt.id}`,
          userName: this.getUserNameById(attempt.userId),
          time: attempt.attemptTime,
          status: CheckInStatus.FAILED,
          statusText: '未通过',
          message: this.getAttemptMessage(attempt),
          score: attempt.compareScore
        };
        return activity;
      });
    const combined: CheckInActivity[] = [];
    recordActivities.forEach((activity: CheckInActivity) => {
      combined.push(activity);
    });
    attemptActivities.forEach((activity: CheckInActivity) => {
      combined.push(activity);
    });
    combined.sort((left: CheckInActivity, right: CheckInActivity) => right.time - left.time);
    this.checkInActivities = combined.slice(0, 40);
  }

  private getAttemptMessage(attempt: CheckInAttempt): string {
    if (attempt.stage === CheckInAttemptStage.LOCATION) {
      return `位置校验未通过：${attempt.failReason}`;
    }
    if (attempt.stage === CheckInAttemptStage.LIVENESS) {
      return `活体检测未通过：${attempt.failReason}`;
    }
    if (attempt.stage === CheckInAttemptStage.CAPTURE) {
      return `拍照未完成：${attempt.failReason}`;
    }
    if (attempt.stage === CheckInAttemptStage.FACE) {
      return `人脸验证未通过：${attempt.failReason}`;
    }
    return attempt.failReason;
  }

  private appendCheckInActivity(status: CheckInStatus, message: string, score: number = 0): boolean {
    if (this.activeAttemptRecorded) {
      return false;
    }
    this.activeAttemptRecorded = true;
    this.activitySequence += 1;
    const activity: CheckInActivity = {
      id: `attempt-${Date.now()}-${this.activitySequence}`,
      userName: this.selectedUserName || '未选择人员',
      time: Date.now(),
      status: status,
      statusText: status === CheckInStatus.NORMAL ? '正常' :
                 status === CheckInStatus.LATE ? '迟到' : '未通过',
      message: message,
      score: score
    };
    this.checkInActivities = [activity, ...this.checkInActivities].slice(0, 40);
    return true;
  }

  private persistFailedAttempt(
    stage: string,
    message: string,
    score: number = 0,
    livenessPassed: boolean = false
  ): void {
    if (!this.currentSession || this.selectedUserId < 0) {
      return;
    }
    const locationPassed = !this.currentSession.enableLocationCheck || (this.pendingLocationCheck?.passed === true);
    const distanceMeters = this.pendingLocationCheck?.distanceMeters ?? 0;
    this.attendanceService.recordCheckInAttempt({
      sessionId: this.currentSession.id,
      userId: this.selectedUserId,
      attemptTime: Date.now(),
      stage: stage,
      success: false,
      failReason: message,
      compareScore: score,
      livenessPassed: livenessPassed,
      locationPassed: locationPassed,
      distanceMeters: distanceMeters
    }).catch((error: Error) => {
      Logger.warn('记录失败签到尝试异常: %{public}s', error.message);
    });
  }

  private hasSessionLocationPoint(): boolean {
    return this.sessionLatitude !== 0 || this.sessionLongitude !== 0;
  }

  private buildGeoFenceConfig(): GeoFenceConfig | undefined {
    if (!this.sessionLocationEnabled) {
      return undefined;
    }
    return {
      enableLocationCheck: true,
      locationName: this.sessionLocationName.trim() || '当前教室',
      latitude: this.sessionLatitude,
      longitude: this.sessionLongitude,
      radiusMeters: this.sessionRadiusMeters,
      locationAccuracy: this.sessionLocationAccuracy
    };
  }

  private resetSessionLocationDraft(): void {
    this.sessionLocationEnabled = false;
    this.sessionLocationName = '当前教室';
    this.sessionRadiusMeters = 100;
    this.sessionLatitude = 0;
    this.sessionLongitude = 0;
    this.sessionLocationAccuracy = 0;
    this.sessionLocationMessage = '';
    this.currentLocationMessage = '';
  }

  private async locateSessionPoint(): Promise<void> {
    if (this.isLocatingSessionPoint) {
      return;
    }
    const hostContext = this.getUIContext().getHostContext();
    if (!hostContext) {
      this.sessionLocationMessage = '无法获取应用上下文';
      return;
    }

    this.isLocatingSessionPoint = true;
    this.sessionLocationMessage = '正在获取当前 Pad 位置...';
    try {
      const result = await LocationAdapter.getCurrentLocation(hostContext);
      if (!result.success || !result.location) {
        this.sessionLocationMessage = result.message;
        this.showToast(result.message, 2600);
        return;
      }
      this.sessionLatitude = result.location.latitude;
      this.sessionLongitude = result.location.longitude;
      this.sessionLocationAccuracy = result.location.accuracy;
      this.sessionLocationMessage = `已记录当前 Pad 位置，精度约 ${Math.round(result.location.accuracy)} 米`;
      this.showToast('已使用当前 Pad 位置作为签到点');
    } finally {
      this.isLocatingSessionPoint = false;
    }
  }

  private buildGeoFenceConfigFromSession(session: AttendanceSession): GeoFenceConfig {
    return {
      enableLocationCheck: session.enableLocationCheck,
      locationName: session.locationName,
      latitude: session.latitude,
      longitude: session.longitude,
      radiusMeters: session.radiusMeters,
      locationAccuracy: session.locationAccuracy
    };
  }

  private async verifyCurrentPadLocation(context: Context): Promise<boolean> {
    if (!this.currentSession || !this.currentSession.enableLocationCheck) {
      this.pendingLocationCheck = null;
      this.currentLocationMessage = '';
      return true;
    }

    this.currentStep = 0;
    this.stepText = '校验签到地点';
    this.currentLocationMessage = '正在校验当前 Pad 位置...';
    const fetchResult = await LocationAdapter.getCurrentLocation(context);
    if (!fetchResult.success || !fetchResult.location) {
      const failedResult: LocationCheckResult = {
        status: fetchResult.status,
        passed: false,
        message: fetchResult.message,
        distanceMeters: 0
      };
      this.pendingLocationCheck = failedResult;
      this.currentLocationMessage = fetchResult.message;
      this.finishCheckInFailure(fetchResult.message, CheckInAttemptStage.LOCATION);
      return false;
    }

    const checkResult = GeoFenceService.check(
      this.buildGeoFenceConfigFromSession(this.currentSession),
      fetchResult.location
    );
    this.pendingLocationCheck = checkResult;
    this.currentLocationMessage = checkResult.message;
    if (!checkResult.passed) {
      this.finishCheckInFailure(checkResult.message, CheckInAttemptStage.LOCATION);
      return false;
    }
    return true;
  }

  private getActivityDotColor(status: CheckInStatus): string {
    if (status === CheckInStatus.NORMAL) return Colors.success;
    if (status === CheckInStatus.LATE) return Colors.warning;
    return Colors.danger;
  }

  private getActivityDotBgColor(status: CheckInStatus): string {
    if (status === CheckInStatus.NORMAL) return Colors.successBgAlt;
    if (status === CheckInStatus.LATE) return Colors.warningBg;
    return Colors.dangerBg;
  }

  private getActivityMessageColor(status: CheckInStatus): string {
    if (status === CheckInStatus.NORMAL || status === CheckInStatus.LATE) return Colors.textSecondary;
    return Colors.dangerDark;
  }

  private getActivityTickerText(): string {
    if (this.checkInActivities.length === 0) {
      return '暂无签到动态，完成一次签到后将在这里实时滚动显示';
    }
    return this.checkInActivities.slice(0, 8).map((activity: CheckInActivity) => {
      const scoreText = activity.score > 0 ? ` ${(activity.score * 100).toFixed(0)}%` : '';
      return `${DateUtils.formatTime(activity.time)} ${activity.userName} ${activity.statusText}${scoreText} ${activity.message}`;
    }).join('     |     ');
  }

  private async createSession(): Promise<void> {
    if (this.selectedCourseId <= 0) {
      this.showToast('请先在教学组织中创建课程');
      return;
    }
    if (this.sessionLocationEnabled && !this.hasSessionLocationPoint()) {
      this.showToast('请先使用当前 Pad 位置作为签到点', 2600);
      return;
    }
    const course = this.courses.find((item: Course) => item.id === this.selectedCourseId);
    const title = this.newSessionTitle.trim() ||
      `${course?.name ?? '课程'} ${DateUtils.formatDate(Date.now())}`;
    try {
      await this.attendanceService.createSession(title, this.selectedCourseId, this.buildGeoFenceConfig());
      this.showCreateSession = false;
      this.newSessionTitle = '';
      this.resetSessionLocationDraft();
      await this.loadData();
      this.showToast('签到场次已创建');
    } catch (error) {
      this.showToast(error instanceof Error ? error.message : '创建场次失败', 3000);
    }
  }

  private async endCurrentSession(): Promise<void> {
    if (!this.currentSession) return;
    try {
      await this.attendanceService.endSession(this.currentSession.id);
      this.selectedUserId = -1;
      this.selectedUserName = '';
      await this.loadData();
      this.showToast('本场签到已结束');
    } catch (error) {
      this.showToast('结束场次失败');
    }
  }

  private async handleFaceCheckIn(): Promise<void> {
    if (this.isChecking) return;
    if (!this.currentSession) {
      this.showToast('请先发起签到');
      return;
    }
    if (this.selectedUserId < 0) {
      this.showToast('请先选择签到人员');
      return;
    }
    const selectedUser = this.allUsers.find((user: UserModel) => user.id === this.selectedUserId);
    if (!selectedUser?.faceEnrolled) {
      this.showToast(`${selectedUser?.name ?? '该用户'}尚未录入人脸`, 3000);
      return;
    }

    this.isChecking = true;
    this.showResult = false;
    this.lastScore = 0;
    this.displayScore = 0;
    this.resultOpacity = 0;
    this.activeAttemptRecorded = false;
    this.pendingLocationCheck = null;
    this.currentStep = 0;
    this.stepText = this.currentSession.enableLocationCheck ? '校验签到地点' : '检查相机权限';

    try {
      const context = this.getUIContext().getHostContext();
      if (!context) {
        throw new Error('无法获取应用上下文');
      }

      const locationReady = await this.verifyCurrentPadLocation(context);
      if (!locationReady) {
        return;
      }

      if (SettingsService.getInstance().isLivenessEnabled()) {
        this.currentStep = 1;
        this.stepText = '进行活体检测';
        const started = await LivenessAdapter.startLivenessDetection(context);
        if (!started) {
          this.finishCheckInFailure('活体检测启动失败，请检查相机权限或设备支持', CheckInAttemptStage.LIVENESS);
          return;
        }
        this.awaitingLivenessResult = true;
        return;
      }

      await this.completeFaceCheckIn(context, false);
    } catch (error) {
      Logger.error('签到启动异常: %{public}s', JSON.stringify(error));
      this.finishCheckInFailure(error instanceof Error ? error.message : '签到过程发生异常');
    }
  }

  private async resumeAfterLiveness(): Promise<void> {
    const context = this.getUIContext().getHostContext();
    if (!context) {
      throw new Error('无法获取应用上下文');
    }
    this.currentStep = 1;
    this.stepText = '读取活体检测结果';
    const result = await LivenessAdapter.getLivenessResult(context);
    if (!result.passed) {
      this.finishCheckInFailure(result.message, CheckInAttemptStage.LIVENESS);
      return;
    }
    await this.completeFaceCheckIn(context, true, result.pixelMap);
  }

  private async completeFaceCheckIn(
    context: Context,
    livenessPassed: boolean,
    livenessPixelMap?: image.PixelMap
  ): Promise<void> {
    let capturedPixelMap = livenessPixelMap;
    try {
      if (!capturedPixelMap) {
        this.currentStep = 0;
        this.stepText = livenessPassed ? '活体通过，请补拍正脸' : '打开前置相机';
        capturedPixelMap = await CameraAdapter.capturePhoto(context);
      }
      if (!capturedPixelMap) {
        this.finishCheckInFailure('未拍摄照片，签到已取消', CheckInAttemptStage.CAPTURE, 0, livenessPassed);
        return;
      }
      if (!this.currentSession) {
        this.finishCheckInFailure('当前签到场次已结束');
        return;
      }

      // 系统相机返回时页面会重新显示，显式等待 Vision 引擎恢复，避免生命周期并发。
      await FaceVisionAdapter.initAll();
      const result = await this.attendanceService.checkInWithFace(
        this.currentSession.id,
        this.selectedUserId,
        capturedPixelMap,
        livenessPassed,
        this.pendingLocationCheck ?? undefined,
        (stage: number) => {
          this.currentStep = stage;
          if (stage === 2) this.stepText = '评估人脸与图像质量';
          if (stage === 3) this.stepText = '进行人脸比对';
          if (stage === 4) this.stepText = '写入签到结果';
        }
      );

      this.currentStep = 4;
      this.checkResultSuccess = result.success;
      this.checkResultMessage = result.message;
      this.lastScore = result.compareScore ?? 0;
      this.showResult = true;
      // 触发分数滚动动画
      this.displayScore = 0;
      this.resultOpacity = 0;
      this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
        this.resultOpacity = 1;
      });
      this.getUIContext().animateTo({ duration: 800, curve: Curve.EaseOut }, () => {
        this.displayScore = this.lastScore;
      });
      const activityAppended = this.appendCheckInActivity(
        result.record?.status ?? CheckInStatus.FAILED,
        result.message,
        result.compareScore ?? 0
      );
      if (!result.success && activityAppended) {
        this.persistFailedAttempt(CheckInAttemptStage.FACE, result.message, result.compareScore ?? 0, livenessPassed);
      }
      if (result.success) {
        await this.loadData();
        this.selectedUserId = -1;
        this.selectedUserName = '';
      }
    } catch (error) {
      Logger.error('签到处理异常: %{public}s', JSON.stringify(error));
      this.finishCheckInFailure('签到过程发生异常');
    } finally {
      capturedPixelMap?.release();
      this.pendingLocationCheck = null;
      this.isChecking = false;
      this.stepText = '';
    }
  }

  private finishCheckInFailure(
    message: string,
    stage: string = CheckInAttemptStage.SYSTEM,
    score: number = this.lastScore,
    livenessPassed: boolean = false
  ): void {
    this.currentStep = 4;
    this.checkResultSuccess = false;
    this.checkResultMessage = message;
    this.showResult = true;
    this.resultOpacity = 0;
    this.isChecking = false;
    this.awaitingLivenessResult = false;
    this.stepText = '';
    const activityAppended = this.appendCheckInActivity(CheckInStatus.FAILED, message, score);
    if (activityAppended) {
      this.persistFailedAttempt(stage, message, score, livenessPassed);
    }
    this.pendingLocationCheck = null;
    this.getUIContext().animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
      this.resultOpacity = 1;
    });
    this.isChecking = false;
    this.stepText = '';
  }

  build() {
    Stack() {
      Column() {
        this.header()

        if (this.compactMode) {
          Stack({ alignContent: Alignment.Bottom }) {
            Scroll() {
              Column() {
                this.sessionSummary()
                this.statsStrip()
                this.peoplePanel(false)
              }
              .width('100%')
              .padding({ left: 12, right: 12, top: 12, bottom: 220 })
            }
            .width('100%')
            .height('100%')
            this.checkInActionBar()
          }
          .layoutWeight(1)
          .width('100%')
        } else if (this.expandedMode) {
          Row() {
            Column() {
              this.sessionSummary()
              this.statsPanel()
            }
            .width(230)
            .height('100%')
            .padding(12)
            .backgroundColor(Colors.bg)

            this.peoplePanel(true)

            Column() {
              this.recentPanel(false)
            }
            .width(290)
            .height('100%')
            .padding(12)
            .backgroundColor(Colors.bg)
          }
          .layoutWeight(1)
          .width('100%')
        } else {
          Row() {
            Column() {
              this.sessionSummary()
              this.statsPanel()
              this.recentPanel(true)
            }
            .width('38%')
            .height('100%')
            .padding(12)
            this.peoplePanel(true)
          }
          .layoutWeight(1)
          .width('100%')
        }

        AppBottomNav({ active: 'home' })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Colors.bg)

      if (this.showCreateSession) {
        this.createSessionDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private header() {
    Row() {
      Column() {
        Text('FaceCheck')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.primary)
        Text('一起刷脸签到')
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      if (this.currentSession) {
        Column() {
          Text(this.currentSession.courseName)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.textPrimary)
          Text('签到进行中')
            .fontSize(11)
            .fontColor(Colors.success)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.End)
      } else {
        FaceEnrollButton() {
          Button('发起签到')
            .height(36)
            .fontSize(13)
            .backgroundColor(Colors.primary)
            .borderRadius(6)
            .shadow(Shadows.button)
            .onClick(() => { this.showCreateSession = true; })
        }
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 18, right: 18 })
    .backgroundColor(Colors.card)
    .border({ width: { bottom: 0.5 }, color: Colors.border })
  }

  @Builder
  private sessionSummary() {
    Column() {
      if (this.currentSession) {
        Text(this.currentSession.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
          .maxLines(2)
        Text(this.currentSession.courseName)
          .fontSize(13)
          .fontColor(Colors.primary)
          .margin({ top: 5 })
        Text(`开始于 ${DateUtils.formatTime(this.currentSession.startTime)}`)
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 5 })
        if (this.currentSession.enableLocationCheck) {
          LocationStatusCard({
            locationEnabled: true,
            locationName: this.currentSession.locationName,
            radiusMeters: this.currentSession.radiusMeters,
            latitude: this.currentSession.latitude,
            longitude: this.currentSession.longitude,
            accuracy: this.currentSession.locationAccuracy,
            message: this.currentLocationMessage || '刷脸前将校验当前 Pad 是否仍在范围内',
            passed: true
          })
            .margin({ top: 12 })
        }
        Column() {
          FaceEnrollButton() {
            Button('结束本场')
              .height(34)
              .fontSize(12)
              .fontColor(Colors.danger)
              .backgroundColor(Colors.dangerBg)
              .borderRadius(6)
              .shadow(Shadows.danger)
              .onClick(() => this.endCurrentSession())
          }
        }
        .margin({ top: 14 })
      } else {
        Text('暂无进行中的签到')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
        Text('选择课程并生成固定应到名单')
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 5, bottom: 14 })
        FaceEnrollButton() {
          Button('发起新签到')
            .height(38)
            .fontSize(13)
            .backgroundColor(Colors.primary)
            .borderRadius(6)
            .shadow(Shadows.button)
            .onClick(() => { this.showCreateSession = true; })
        }
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(Colors.card)
    .borderRadius(12)
    .shadow(Shadows.card)
    .margin({ bottom: 10 })
  }

  @Builder
  private statsStrip() {
    Row() {
      this.statCell('应到', () => this.stats.totalUsers, Colors.primary)
      this.statCell('已到', () => this.stats.checkedIn, Colors.success)
      this.statCell('迟到', () => this.stats.lateCount, Colors.warning)
      this.statCell('未到', () => this.stats.absentCount, Colors.danger)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(Colors.card)
    .borderRadius(12)
    .shadow(Shadows.card)
    .margin({ bottom: 10 })
  }

  @Builder
  private statsPanel() {
    Column() {
      Text('本场统计')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.textPrimary)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 10 })
      this.statRow('应到人数', () => this.stats.totalUsers, Colors.primary)
      this.statRow('已签到', () => this.stats.checkedIn, Colors.success)
      this.statRow('迟到', () => this.stats.lateCount, Colors.warning)
      this.statRow('未签到', () => this.stats.absentCount, Colors.danger)
      Divider().color(Colors.border).margin({ top: 6, bottom: 12 })
      CircleProgress({
        value: this.attendanceRate,
        circleSize: 90,
        strokeWidth: 9,
        color: Colors.success,
        label: '出勤率'
      })
        .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Colors.card)
    .borderRadius(12)
    .shadow(Shadows.card)
  }

  @Builder
  private statCell(label: string, value: () => number, color: string) {
    Column() {
      Text(value().toString())
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(11)
        .fontColor(Colors.textTertiary)
        .margin({ top: 3 })
    }
    .layoutWeight(1)
  }

  @Builder
  private statRow(label: string, value: () => number, color: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor(Colors.textTertiary)
      Blank()
      Text(value().toString())
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
  }

  @Builder
  private peoplePanel(fillHeight: boolean) {
    Column() {
      Row() {
        Column() {
          Text('应到人员')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.textPrimary)
          Text(this.currentSession ? '名单已按场次冻结' : '发起签到后按课程生成名单')
            .fontSize(12)
            .fontColor(Colors.textTertiary)
            .margin({ top: 3 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text(`${this.filteredUsers.length} 人`)
          .fontSize(12)
          .fontColor(Colors.primary)
      }
      .width('100%')
      .padding({ bottom: 12 })

      TextInput({ placeholder: '搜索姓名或学号', text: this.searchKeyword })
        .width('100%')
        .height(40)
        .backgroundColor(Colors.bg)
        .borderRadius(6)
        .margin({ bottom: 8 })
        .onChange((value: string) => {
          this.searchKeyword = value;
          this.filterUsers();
        })

      if (fillHeight) {
        List() {
          ForEach(this.filteredUsers, (user: UserModel) => {
            this.userListItem(user)
          }, (user: UserModel) => user.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
        .divider({ strokeWidth: 0.5, color: Colors.border, startMargin: 45 })
      } else {
        ForEach(this.filteredUsers, (user: UserModel) => {
          this.userRow(user)
        }, (user: UserModel) => user.id.toString())
      }

      if (!this.compactMode) {
        this.progressPanel()
        this.resultPanel()
        this.checkInButton()
      }
    }
    .layoutWeight(fillHeight ? 1 : 0)
    .height(fillHeight ? '100%' : undefined)
    .padding(16)
    .margin(fillHeight ? 12 : { bottom: 10 })
    .backgroundColor(Colors.card)
    .borderRadius(12)
    .shadow(Shadows.card)
  }

  @Builder
  private userListItem(user: UserModel) {
    ListItem() {
      this.userRow(user)
    }
  }

  @Builder
  private userRow(user: UserModel) {
    Row() {
      Text(user.name.charAt(0))
        .width(34)
        .height(34)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.white)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.selectedUserId === user.id ? Colors.primary : Colors.textTertiary)
        .borderRadius(17)
        .margin({ right: 10 })
      Column() {
        Text(user.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(Colors.textPrimary)
        Text(`${user.studentNo} · ${user.className}`)
          .fontSize(11)
          .fontColor(Colors.textTertiary)
          .margin({ top: 3 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(user.faceEnrolled ? '已录入' : '未录入')
        .fontSize(11)
        .fontColor(user.faceEnrolled ? Colors.success : Colors.danger)
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 10, bottom: 10 })
    .backgroundColor(this.selectedUserId === user.id ? Colors.primaryBg : Colors.card)
    .borderRadius(6)
    .onClick(() => {
      this.selectedUserId = user.id;
      this.selectedUserName = user.name;
      this.showResult = false;
      this.currentStep = -1;
    })
  }

  @Builder
  private progressPanel() {
    if (this.isChecking || this.currentStep >= 0) {
      Row() {
        this.stepNode(0, this.currentSession?.enableLocationCheck ? '定位' : '权限')
        this.stepLine(1)
        this.stepNode(1, '活体')
        this.stepLine(2)
        this.stepNode(2, '质量')
        this.stepLine(3)
        this.stepNode(3, '比对')
        this.stepLine(4)
        this.stepNode(4, '结果')
      }
      .width('100%')
      .padding({ top: 12, bottom: 8 })
    }
  }

  @Builder
  private stepNode(index: number, label: string) {
    Column() {
      Text(index < this.currentStep ? '✓' : (index + 1).toString())
        .width(24)
        .height(24)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(index <= this.currentStep ? Colors.white : Colors.textTertiary)
        .textAlign(TextAlign.Center)
        .backgroundColor(index <= this.currentStep ? Colors.primary : Colors.border)
        .borderRadius(12)
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
      .margin({ left: 3, right: 3, bottom: 14 })
  }

  @Builder
  private resultPanel() {
    if (this.showResult) {
      Row() {
        Column() {
          Text(this.checkResultSuccess ? '签到成功' : '签到未通过')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.checkResultSuccess ? Colors.success : Colors.danger)
          Text(this.checkResultMessage)
            .fontSize(12)
            .fontColor(Colors.textPrimary)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.lastScore > 0) {
          Text(`${Math.round(this.displayScore * 100)}%`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.checkResultSuccess ? Colors.success : Colors.danger)
        }
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.checkResultSuccess ? Colors.successBg : Colors.dangerBg)
      .borderRadius(6)
      .margin({ top: 8 })
      .opacity(this.resultOpacity)
    }
  }

  @Builder
  private checkInButton() {
    Column() {
      FaceEnrollButton({ animationEnabled: this.selectedUserId >= 0 && !this.isChecking }) {
        Button() {
          Row() {
            Image($r('app.media.icon_camera'))
              .width(19)
              .height(19)
              .fillColor(Colors.white)
            Text(this.isChecking ? (this.stepText || '处理中') :
              (this.selectedUserName ? `为 ${this.selectedUserName} 签到` : '选择人员后刷脸签到'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Colors.white)
              .margin({ left: 7 })
              .maxLines(1)
          }
        }
        .width('100%')
        .height(48)
        .type(ButtonType.Normal)
        .backgroundColor(this.selectedUserId >= 0 && !this.isChecking ? Colors.primary : Colors.disabled)
        .borderRadius(6)
        .shadow(this.selectedUserId >= 0 && !this.isChecking ? Shadows.button : { radius: 0, color: 'transparent', offsetY: 0 })
        .enabled(this.selectedUserId >= 0 && !this.isChecking)
        .onClick(() => this.handleFaceCheckIn())
      }
    }
    .width('100%')
    .margin({ top: 10 })
  }

  @Builder
  private checkInActionBar() {
    Column() {
      this.compactActivityTicker()
      this.progressPanel()
      this.resultPanel()
      this.checkInButton()
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 10 })
    .backgroundColor(Colors.card)
    .border({ width: { top: 0.5 }, color: Colors.border })
  }

  @Builder
  private compactActivityTicker() {
    Row() {
      Row() {
        Circle()
          .width(7)
          .height(7)
          .fill(this.checkInActivities.length > 0
            ? this.getActivityDotColor(this.checkInActivities[0].status) : Colors.success)
        Text('实时')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
          .margin({ left: 6 })
      }
      .width(54)
      Text(this.checkInActivities.length > 0 ? this.checkInActivities[0].userName : '暂无签到动态')
        .layoutWeight(1)
        .height(30)
        .fontSize(12)
        .fontColor(this.checkInActivities.length > 0
          ? this.getActivityMessageColor(this.checkInActivities[0].status) : Colors.textSecondary)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .maxLines(1)
    }
    .width('100%')
    .height(38)
    .padding({ left: 10, right: 10 })
      .backgroundColor(this.checkInActivities.length > 0
        ? this.getActivityDotBgColor(this.checkInActivities[0].status) : Colors.successBgAlt)
    .borderRadius(6)
    .margin({ bottom: 6 })
  }

  @Builder
  private locationSetupPanel() {
    Column() {
      Row() {
        Column() {
          Text('地理围栏')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Colors.textPrimary)
          Text('发起时记录当前 Pad 位置，刷脸前再次校验')
            .fontSize(11)
            .fontColor(Colors.textTertiary)
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.sessionLocationEnabled })
          .selectedColor(Colors.primary)
          .onChange((isOn: boolean) => {
            this.sessionLocationEnabled = isOn;
            if (!isOn) {
              this.sessionLocationMessage = '';
            }
          })
      }
      .width('100%')

      if (this.sessionLocationEnabled) {
        LocationStatusCard({
          locationEnabled: true,
          locationName: this.sessionLocationName,
          radiusMeters: this.sessionRadiusMeters,
          latitude: this.sessionLatitude,
          longitude: this.sessionLongitude,
          accuracy: this.sessionLocationAccuracy,
          message: this.sessionLocationMessage,
          loading: this.isLocatingSessionPoint,
          passed: this.hasSessionLocationPoint()
        })
          .margin({ top: 10 })

        TextInput({ placeholder: '地点名称，例如 教学楼 A306', text: this.sessionLocationName })
          .width('100%')
          .height(38)
          .fontSize(13)
          .backgroundColor(Colors.bg)
          .borderRadius(6)
          .margin({ top: 10 })
          .onChange((value: string) => { this.sessionLocationName = value; })

        Row() {
          ForEach(this.radiusOptions, (radius: number) => {
            Text(`${radius}m`)
              .fontSize(12)
              .fontColor(this.sessionRadiusMeters === radius ? Colors.white : Colors.textSecondary)
              .textAlign(TextAlign.Center)
              .width(58)
              .height(30)
              .backgroundColor(this.sessionRadiusMeters === radius ? Colors.primary : Colors.bg)
              .borderRadius(6)
              .margin({ right: 6 })
              .onClick(() => { this.sessionRadiusMeters = radius; })
          }, (radius: number) => radius.toString())
        }
        .width('100%')
        .margin({ top: 10 })

        Column() {
          FaceEnrollButton({ animationEnabled: !this.isLocatingSessionPoint }) {
            Button(this.isLocatingSessionPoint ? '正在定位' : '使用当前 Pad 位置')
              .width('100%')
              .height(38)
              .fontSize(13)
              .backgroundColor(Colors.primary)
              .borderRadius(6)
              .enabled(!this.isLocatingSessionPoint)
              .onClick(() => this.locateSessionPoint())
          }
        }
        .width('100%')
        .margin({ top: 10 })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor(Colors.primaryLight)
    .borderRadius(8)
    .margin({ top: 12, bottom: 2 })
  }

  @Builder
  private recentPanel(dense: boolean) {
    Column() {
      Text('实时签到动态')
        .fontSize(dense ? 14 : 16)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.textPrimary)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })
      if (this.checkInActivities.length === 0) {
        Text('暂无签到动态')
          .fontSize(13)
          .fontColor(Colors.textTertiary)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 28, bottom: 28 })
      } else {
        List() {
          ForEach(this.checkInActivities.slice(0, 30), (activity: CheckInActivity, index: number) => {
            ListItem() {
              AnimatedCard({ delay: 40 * index }) {
                Row() {
                  Circle()
                    .width(7)
                    .height(7)
                    .fill(this.getActivityDotColor(activity.status))
                    .margin({ right: dense ? 7 : 9 })
                  Column() {
                    Text(activity.userName)
                      .fontSize(dense ? 12 : 13)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Colors.textPrimary)
                    Text(`${DateUtils.formatTime(activity.time)}${activity.score > 0
                      ? ` · ${(activity.score * 100).toFixed(0)}%` : ''}`)
                      .fontSize(dense ? 10 : 11)
                      .fontColor(Colors.textTertiary)
                      .margin({ top: 3 })
                    Text(activity.message)
                      .fontSize(dense ? 10 : 11)
                      .fontColor(this.getActivityMessageColor(activity.status))
                      .maxLines(2)
                      .margin({ top: 3 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  StatusPill({
                    status: activity.status === CheckInStatus.NORMAL ? StatusType.NORMAL :
                            activity.status === CheckInStatus.LATE ? StatusType.LATE :
                            activity.status === CheckInStatus.ABSENT ? StatusType.ABSENT : StatusType.FAILED,
                    text: activity.statusText
                  })
                }
                .width('100%')
                .padding({ top: dense ? 8 : 10, bottom: dense ? 8 : 10 })
                .border({ width: { bottom: 0.5 }, color: Colors.border })
              }
            }
          }, (activity: CheckInActivity) => activity.id)
        }
        .opacity(this.recentPanelOpacity)
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.On)
        .scrollBarColor(Colors.scrollbar)
        .scrollBarWidth(4)
      }
    }
    .width('100%')
    .layoutWeight(1)
    .padding(dense ? 12 : 16)
    .backgroundColor(Colors.card)
    .borderRadius(12)
    .shadow(Shadows.card)
    .margin({ top: dense ? 10 : 0 })
  }

  @Builder
  private createSessionDialog() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.36)')
        .onClick(() => {
          this.showCreateSession = false;
          this.resetSessionLocationDraft();
        })
      Column() {
        Text('发起课程签到')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(Colors.textPrimary)
        Text('创建时会把当前选课学生冻结为本场应到名单')
          .fontSize(12)
          .fontColor(Colors.textTertiary)
          .margin({ top: 5, bottom: 15 })
        Text('选择课程')
          .fontSize(13)
          .fontColor(Colors.textPrimary)
          .alignSelf(ItemAlign.Start)
        Column() {
          ForEach(this.courses, (course: Course) => {
            Row() {
              Text(course.name)
                .fontSize(14)
                .fontColor(Colors.textPrimary)
                .layoutWeight(1)
              Text(course.code)
                .fontSize(11)
                .fontColor(Colors.textTertiary)
              Circle()
                .width(16)
                .height(16)
                .fill(this.selectedCourseId === course.id ? Colors.primary : Colors.card)
                .border({ width: 1.5, color: this.selectedCourseId === course.id ? Colors.primary : Colors.disabled })
                .margin({ left: 10 })
            }
            .width('100%')
            .padding({ top: 11, bottom: 11 })
            .border({ width: { bottom: 0.5 }, color: Colors.border })
            .onClick(() => { this.selectedCourseId = course.id; })
          }, (course: Course) => course.id.toString())
        }
        .width('100%')
        .margin({ top: 6, bottom: 14 })
        TextInput({ placeholder: '场次名称（可不填）', text: this.newSessionTitle })
          .width('100%')
          .height(42)
          .backgroundColor(Colors.bg)
          .borderRadius(6)
          .onChange((value: string) => { this.newSessionTitle = value; })
        this.locationSetupPanel()
        Row() {
          Column() {
            FaceEnrollButton() {
              Button('取消')
                .width('100%')
                .height(42)
                .fontColor(Colors.textPrimary)
                .backgroundColor(Colors.bg)
                .borderRadius(6)
                .onClick(() => {
                  this.showCreateSession = false;
                  this.resetSessionLocationDraft();
                })
            }
          }
          .layoutWeight(1)
          .margin({ right: 6 })
          Column() {
            FaceEnrollButton() {
              Button('创建场次')
                .width('100%')
                .height(42)
                .backgroundColor(Colors.primary)
                .borderRadius(6)
                .onClick(() => this.createSession())
            }
          }
          .layoutWeight(1)
          .margin({ left: 6 })
        }
        .width('100%')
        .margin({ top: 18 })
      }
      .width(this.compactMode ? '90%' : 430)
      .constraintSize({ maxHeight: '82%' })
      .padding(22)
      .backgroundColor(Colors.card)
      .shadow(Shadows.card)
      .borderRadius(Radius.card)
    }
    .width('100%')
    .height('100%')
  }
}
