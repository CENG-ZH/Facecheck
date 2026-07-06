/**
 * 签到尝试记录。
 * 用于保存没有进入正式 attendance_records 的失败尝试，例如位置校验、活体检测或人脸比对失败。
 */
export class CheckInAttemptStage {
  static readonly LOCATION: string = 'location';
  static readonly LIVENESS: string = 'liveness';
  static readonly CAPTURE: string = 'capture';
  static readonly FACE: string = 'face';
  static readonly SYSTEM: string = 'system';
}

export interface CheckInAttempt {
  id: number;
  sessionId: number;
  userId: number;
  attemptTime: number;
  stage: string;
  success: boolean;
  failReason: string;
  compareScore: number;
  livenessPassed: boolean;
  locationPassed: boolean;
  distanceMeters: number;
  createdAt: number;
}

export interface CheckInAttemptDraft {
  sessionId: number;
  userId: number;
  attemptTime: number;
  stage: string;
  success: boolean;
  failReason: string;
  compareScore?: number;
  livenessPassed?: boolean;
  locationPassed?: boolean;
  distanceMeters?: number;
}
