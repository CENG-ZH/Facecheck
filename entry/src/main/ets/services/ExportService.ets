import { fileIo, picker } from '@kit.CoreFileKit';
import { AttendanceRecord, AttendanceSession, CheckInStatus } from '../models/AttendanceModel';
import { CheckInAttempt, CheckInAttemptStage } from '../models/CheckInAttemptModel';
import { UserModel } from '../models/UserModel';
import { DateUtils } from '../utils/DateUtils';

export interface AttendanceAbsentRow {
  sessionId: number;
  userName: string;
  studentNo: string;
  className: string;
}

export class ExportService {
  private escapeCsv(value: string): string {
    return `"${value.replace(/"/g, '""')}"`;
  }

  private statusText(status: CheckInStatus): string {
    if (status === CheckInStatus.NORMAL) return '正常';
    if (status === CheckInStatus.LATE) return '迟到';
    if (status === CheckInStatus.ABSENT) return '缺勤';
    return '失败';
  }

  private locationStatusText(record: AttendanceRecord): string {
    const hasLocation = record.checkLatitude !== 0 || record.checkLongitude !== 0 || record.distanceMeters > 0;
    if (!hasLocation && record.locationPassed) {
      return '未启用';
    }
    return record.locationPassed ? '通过' : '失败';
  }

  private distanceText(record: AttendanceRecord): string {
    if (record.distanceMeters <= 0) {
      return '';
    }
    return `${Math.round(record.distanceMeters)}m`;
  }

  private accuracyText(record: AttendanceRecord): string {
    if (record.checkLocationAccuracy <= 0) {
      return '';
    }
    return `${Math.round(record.checkLocationAccuracy)}m`;
  }

  private attemptLivenessText(attempt: CheckInAttempt): string {
    if (attempt.livenessPassed) {
      return '通过';
    }
    if (attempt.stage === CheckInAttemptStage.LIVENESS) {
      return '未通过';
    }
    return '未检测';
  }

  private attemptLocationText(attempt: CheckInAttempt): string {
    return attempt.locationPassed ? '通过' : '失败';
  }

  private attemptDistanceText(attempt: CheckInAttempt): string {
    if (attempt.distanceMeters <= 0) {
      return '';
    }
    return `${Math.round(attempt.distanceMeters)}m`;
  }

  async exportAttendanceCsv(
    context: Context,
    records: AttendanceRecord[],
    sessions: AttendanceSession[],
    users: UserModel[],
    absentRows: AttendanceAbsentRow[] = [],
    attempts: CheckInAttempt[] = [],
    fileNamePrefix: string = ''
  ): Promise<string> {
    const lines: string[] = [
      [
        '姓名',
        '学号',
        '班级',
        '课程',
        '场次',
        '签到日期',
        '签到时间',
        '匹配度',
        '活体检测',
        '位置校验',
        '距签到点',
        '定位精度',
        '失败原因',
        '状态'
      ]
        .map((value: string) => this.escapeCsv(value))
        .join(',')
    ];

    records.forEach((record: AttendanceRecord) => {
      if (record.status === CheckInStatus.ABSENT) {
        return; // 缺勤记录走 absentRows 逻辑，避免重复
      }
      const user = users.find((item: UserModel) => item.id === record.userId);
      const session = sessions.find((item: AttendanceSession) => item.id === record.sessionId);
      const row = [
        user?.name ?? '历史用户',
        user?.studentNo ? `="${user.studentNo}"` : '',
        user?.className ?? '',
        session?.courseName ?? '历史课程',
        session?.title ?? '',
        DateUtils.formatDate(record.checkInTime),
        DateUtils.formatTime(record.checkInTime),
        `${(record.compareScore * 100).toFixed(1)}%`,
        record.livenessPassed ? '通过' : '未启用',
        this.locationStatusText(record),
        this.distanceText(record),
        this.accuracyText(record),
        record.locationFailReason,
        this.statusText(record.status)
      ];
      lines.push(row.map((value: string) => this.escapeCsv(value)).join(','));
    });
    absentRows.forEach((absent: AttendanceAbsentRow) => {
      const session = sessions.find((item: AttendanceSession) => item.id === absent.sessionId);
      const row = [
        absent.userName,
        absent.studentNo ? `="${absent.studentNo}"` : '',
        absent.className,
        session?.courseName ?? '历史课程',
        session?.title ?? '',
        session ? DateUtils.formatDate(session.startTime) : '',
        '',
        '',
        '未检测',
        '未检测',
        '',
        '',
        '',
        '缺勤'
      ];
      lines.push(row.map((value: string) => this.escapeCsv(value)).join(','));
    });
    attempts.forEach((attempt: CheckInAttempt) => {
      const user = users.find((item: UserModel) => item.id === attempt.userId);
      const session = sessions.find((item: AttendanceSession) => item.id === attempt.sessionId);
      const locationText = session?.enableLocationCheck === true ? this.attemptLocationText(attempt) : '未启用';
      const row = [
        user?.name ?? '历史用户',
        user?.studentNo ? `="${user.studentNo}"` : '',
        user?.className ?? '',
        session?.courseName ?? '历史课程',
        session?.title ?? '',
        DateUtils.formatDate(attempt.attemptTime),
        DateUtils.formatTime(attempt.attemptTime),
        attempt.compareScore > 0 ? `${(attempt.compareScore * 100).toFixed(1)}%` : '',
        this.attemptLivenessText(attempt),
        locationText,
        this.attemptDistanceText(attempt),
        '',
        attempt.failReason,
        '失败尝试'
      ];
      lines.push(row.map((value: string) => this.escapeCsv(value)).join(','));
    });

    const documentPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSaveOptions();
    const dateStr = DateUtils.formatDate(Date.now());
    const fileLabel = fileNamePrefix !== '' ? fileNamePrefix : `考勤报表_${dateStr}`;
    options.newFileNames = [`FaceCheck_${fileLabel}.csv`];
    options.fileSuffixChoices = ['CSV 文件|.csv'];
    const uris = await documentPicker.save(options);
    if (uris.length === 0) {
      throw new Error('未选择保存位置');
    }

    const file = fileIo.openSync(
      uris[0],
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    );
    try {
      fileIo.writeSync(file.fd, `\uFEFF${lines.join('\r\n')}`);
    } finally {
      fileIo.closeSync(file);
    }
    return uris[0];
  }
}
