/**
 * 签到场次模型
 */
export interface AttendanceSession {
  id: number;
  title: string;
  courseId: number;
  courseName: string;
  startTime: number;
  lateTime: number;
  endTime: number;
  status: SessionStatus;
}

/**
 * 场次状态枚举
 */
export enum SessionStatus {
  NOT_STARTED = 0,
  IN_PROGRESS = 1,
  ENDED = 2
}

/**
 * 签到记录模型
 */
export interface AttendanceRecord {
  id: number;
  sessionId: number;
  userId: number;
  checkInTime: number;
  compareScore: number;
  livenessPassed: boolean;
  status: CheckInStatus;
  capturedImagePath: string;
}

/**
 * 新建签到记录时使用的数据模型
 */
export interface AttendanceRecordDraft {
  sessionId: number;
  userId: number;
  checkInTime: number;
  compareScore: number;
  livenessPassed: boolean;
  status: CheckInStatus;
  capturedImagePath: string;
}

/**
 * 签到状态枚举
 */
export enum CheckInStatus {
  NORMAL = 0,
  LATE = 1,
  FAILED = 2,
  ABSENT = 3   // 缺勤——场次结束时自动生成
}

/**
 * 签到结果
 */
export interface CheckInResult {
  success: boolean;
  message: string;
  record?: AttendanceRecord;
  compareScore?: number;
}

/**
 * 人脸检测结果
 */
export interface FaceDetectionResult {
  hasFace: boolean;
  faceCount: number;
  message: string;
  isFrontal: boolean;
}

/**
 * 人脸比对结果
 */
export interface FaceCompareResult {
  isMatch: boolean;
  score: number;
  message: string;
}

/**
 * 签到记录展示项（含用户信息）
 */
export interface AttendanceRecordDisplay {
  id: number;
  sessionTitle: string;
  userName: string;
  studentNo: string;
  className: string;
  checkInTime: number;
  compareScore: number;
  status: CheckInStatus;
}

/**
 * 签到统计
 */
export interface AttendanceStats {
  totalUsers: number;
  checkedIn: number;
  lateCount: number;
  absentCount: number;
}

/**
 * 用户数量统计
 */
export interface UserStats {
  total: number;
  enrolled: number;
}
