import { image } from '@kit.ImageKit';
import { AttendanceDao } from '../database/AttendanceDao';
import { SessionDao } from '../database/SessionDao';
import { UserDao } from '../database/UserDao';
import { SessionMemberDao } from '../database/SessionMemberDao';
import { OrganizationDao } from '../database/OrganizationDao';
import {
  AttendanceRecord,
  AttendanceRecordDraft,
  AttendanceSession,
  AttendanceStats,
  CheckInResult,
  CheckInStatus,
  SessionStatus
} from '../models/AttendanceModel';
import { FaceVisionAdapter } from '../kits/FaceVisionAdapter';
import { CameraAdapter } from '../kits/CameraAdapter';
import { SettingsService } from './SettingsService';
import { Logger } from '../utils/Logger';
import { AttendanceRules } from '../utils/AttendanceRules';
import { UserModel } from '../models/UserModel';

/**
 * 签到业务服务
 *
 * 核心签到流程（参考 dev plan 第六节）：
 * 1. 检查当前场次
 * 2. 查询用户及注册照片
 * 3. 活体检测（启用时）
 * 4. 人脸检测及质量校验
 * 5. Core Vision Kit 人脸比对
 * 6. 判断官方匹配结果与分数
 * 7. 检查重复签到
 * 8. 写入记录
 * 9. 返回成功/失败原因
 */
export class AttendanceService {
  private attendanceDao: AttendanceDao = new AttendanceDao();
  private sessionDao: SessionDao = new SessionDao();
  private userDao: UserDao = new UserDao();
  private sessionMemberDao: SessionMemberDao = new SessionMemberDao();
  private organizationDao: OrganizationDao = new OrganizationDao();

  /**
   * 创建签到场次
   */
  async createSession(title: string, courseId: number = 0): Promise<number> {
    const activeSession = await this.sessionDao.getActiveSession();
    if (activeSession) {
      throw new Error(`已有进行中的场次“${activeSession.title}”，请先结束该场次`);
    }
    const now = Date.now();
    const resolvedCourseId = courseId > 0 ? courseId : await this.organizationDao.getDefaultCourseId();
    if (resolvedCourseId <= 0) {
      throw new Error('请先创建课程');
    }
    const memberCount = await this.organizationDao.getEnrollmentCount(resolvedCourseId);
    if (memberCount <= 0) {
      throw new Error('该课程没有已选课学生，无法发起签到');
    }
    const settings = SettingsService.getInstance().getSettings();
    const lateTime = now + settings.lateMinutes * 60 * 1000;
    const endTime = now + 2 * 60 * 60 * 1000;
    const sessionId = await this.sessionDao.insert(title, resolvedCourseId, now, lateTime, endTime);
    try {
      const snapshotCount = await this.sessionMemberDao.createSnapshot(sessionId, resolvedCourseId);
      if (snapshotCount <= 0) {
        throw new Error('未能生成应到名单');
      }
      return sessionId;
    } catch (error) {
      await this.sessionDao.delete(sessionId);
      const caughtError = error as Error;
      throw new Error(caughtError.message);
    }
  }

  /**
   * 获取当前活跃场次
   */
  async getActiveSession(): Promise<AttendanceSession | null> {
    return await this.sessionDao.getActiveSession();
  }

  /**
   * 结束场次
   */
  async endSession(sessionId: number): Promise<void> {
    await this.sessionDao.endSession(sessionId, Date.now());
  }

  /**
   * 获取所有场次
   */
  async getAllSessions(): Promise<AttendanceSession[]> {
    return await this.sessionDao.getAll();
  }

  /**
   * 执行完整签到流程（带人脸比对）
   *
   * @param sessionId 签到场次ID
   * @param userId 用户ID
   * @param capturedPixelMap 现场拍摄的人脸 PixelMap
   * @param livenessPassed 活体检测是否已通过（在调用前已完成）
   * @returns 签到结果
   */
  async checkInWithFace(
    sessionId: number,
    userId: number,
    capturedPixelMap: image.PixelMap,
    livenessPassed: boolean = false,
    onStage?: (stage: number) => void
  ): Promise<CheckInResult> {
    try {
      // 1. 检查场次是否存在且活跃
      const session = await this.sessionDao.getById(sessionId);
      if (!session) {
        return { success: false, message: '签到场次不存在' };
      }
      if (session.status !== SessionStatus.IN_PROGRESS) {
        return { success: false, message: '签到场次已结束' };
      }

      const isSessionMember = await this.sessionMemberDao.isMember(sessionId, userId);
      if (!isSessionMember) {
        return { success: false, message: '该学生不在本场次应到名单中' };
      }

      // 2. 检查用户是否存在且已录入人脸
      const user = await this.userDao.getById(userId);
      if (!user) {
        return { success: false, message: '用户不存在' };
      }
      if (!user.faceEnrolled || !user.faceImagePath) {
        return { success: false, message: `${user.name} 尚未录入人脸，请先完成人脸录入` };
      }

      // 3. 检查是否已签到
      const alreadyCheckedIn = await this.attendanceDao.hasCheckedIn(sessionId, userId);
      if (alreadyCheckedIn) {
        return { success: false, message: `${user.name} 在此场次已签到，不可重复签到` };
      }

      // 4. 人脸检测（质量校验）
      onStage?.(2);
      Logger.info('签到服务: 开始检测现场人脸, sessionId=%{public}s, userId=%{public}s',
        sessionId.toString(), userId.toString());
      const detection = await FaceVisionAdapter.detect(capturedPixelMap);
      Logger.info('签到服务: 人脸检测完成, hasFace=%{public}s, count=%{public}s, frontal=%{public}s',
        detection.hasFace.toString(), detection.faceCount.toString(), detection.isFrontal.toString());
      if (!detection.hasFace) {
        return { success: false, message: detection.message };
      }
      if (detection.faceCount > 1) {
        return { success: false, message: detection.message };
      }
      if (!detection.isFrontal) {
        return { success: false, message: detection.message };
      }

      // 5. 加载注册照片并进行 1:1 人脸比对
      const registeredPixelMap = await CameraAdapter.loadPixelMap(user.faceImagePath);
      if (!registeredPixelMap) {
        return { success: false, message: '无法加载注册照片，请重新录入人脸' };
      }

      onStage?.(3);
      Logger.info('签到服务: 开始加载注册照片并执行人脸比对');
      const compareResult = await FaceVisionAdapter.compare(registeredPixelMap, capturedPixelMap);
      // registeredPixelMap 由 FaceVisionAdapter.compare() finally 释放，无需手动处理

      // 6. 判断比对结果
      // 优先使用官方 isSamePerson 判断，同时记录分数供后续分析
      const threshold = SettingsService.getInstance().getFaceThresholdNormalized();
      Logger.info('签到服务: 比对判定, isMatch=%{public}s, score=%{public}s, threshold=%{public}s',
        compareResult.isMatch.toString(), compareResult.score.toString(), threshold.toString());
      if (!compareResult.isMatch || compareResult.score < threshold) {
        return {
          success: false,
          message: `人脸验证未通过，匹配度 ${(compareResult.score * 100).toFixed(0)}%，要求至少 ${(threshold * 100).toFixed(0)}%`,
          compareScore: compareResult.score
        };
      }

      // 7. 判断签到状态
      const now = Date.now();
      const status = AttendanceRules.resolveStatus(now, session.lateTime);

      // 8. 写入签到记录
      const record: AttendanceRecordDraft = {
        sessionId: sessionId,
        userId: userId,
        checkInTime: now,
        compareScore: compareResult.score,
        livenessPassed: livenessPassed,
        status: status,
        capturedImagePath: ''
      };

      onStage?.(4);
      const recordId = await this.attendanceDao.insert(record);
      const fullRecord: AttendanceRecord = {
        id: recordId,
        sessionId: record.sessionId,
        userId: record.userId,
        checkInTime: record.checkInTime,
        compareScore: record.compareScore,
        livenessPassed: record.livenessPassed,
        status: record.status,
        capturedImagePath: record.capturedImagePath
      };

      // 9. 返回结果
      const statusText = status === CheckInStatus.LATE ? '（迟到）' : '';
      return {
        success: true,
        message: `${user.name} 签到成功${statusText}，匹配度 ${(compareResult.score * 100).toFixed(0)}%`,
        record: fullRecord,
        compareScore: compareResult.score
      };
    } catch (error) {
      Logger.error('签到失败: %{public}s', JSON.stringify(error));
      const errorMessage = error instanceof Error ? error.message : '签到过程发生未知错误';
      return { success: false, message: errorMessage };
    }
  }

  /**
   * 获取场次签到统计
   */
  async getSessionStats(sessionId: number): Promise<AttendanceStats> {
    const totalUsers = await this.sessionMemberDao.getCount(sessionId);
    return await this.attendanceDao.getSessionStats(sessionId, totalUsers);
  }

  async getSessionMembers(sessionId: number): Promise<UserModel[]> {
    return await this.sessionMemberDao.getMembers(sessionId);
  }

  /**
   * 获取最近签到记录
   */
  async getRecentRecords(limit: number = 10): Promise<AttendanceRecord[]> {
    return await this.attendanceDao.getRecentRecords(limit);
  }

  /**
   * 获取所有签到记录
   */
  async getAllRecords(): Promise<AttendanceRecord[]> {
    return await this.attendanceDao.getAll();
  }

  /**
   * 获取某场次的签到记录
   */
  async getSessionRecords(sessionId: number): Promise<AttendanceRecord[]> {
    return await this.attendanceDao.getBySessionId(sessionId);
  }
}
