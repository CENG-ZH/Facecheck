import { fileIo, picker } from '@kit.CoreFileKit';
import { AttendanceRecord, AttendanceSession, CheckInStatus } from '../models/AttendanceModel';
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
    return '失败';
  }

  async exportAttendanceCsv(
    context: Context,
    records: AttendanceRecord[],
    sessions: AttendanceSession[],
    users: UserModel[],
    absentRows: AttendanceAbsentRow[] = []
  ): Promise<string> {
    const lines: string[] = [
      ['姓名', '学号', '班级', '课程', '场次', '签到日期', '签到时间', '匹配度', '活体检测', '状态']
        .map((value: string) => this.escapeCsv(value))
        .join(',')
    ];

    records.forEach((record: AttendanceRecord) => {
      const user = users.find((item: UserModel) => item.id === record.userId);
      const session = sessions.find((item: AttendanceSession) => item.id === record.sessionId);
      const row = [
        user?.name ?? '历史用户',
        user?.studentNo ?? '',
        user?.className ?? '',
        session?.courseName ?? '历史课程',
        session?.title ?? '',
        DateUtils.formatDate(record.checkInTime),
        DateUtils.formatTime(record.checkInTime),
        `${(record.compareScore * 100).toFixed(1)}%`,
        record.livenessPassed ? '通过' : '未启用',
        this.statusText(record.status)
      ];
      lines.push(row.map((value: string) => this.escapeCsv(value)).join(','));
    });
    absentRows.forEach((absent: AttendanceAbsentRow) => {
      const session = sessions.find((item: AttendanceSession) => item.id === absent.sessionId);
      const row = [
        absent.userName,
        absent.studentNo,
        absent.className,
        session?.courseName ?? '历史课程',
        session?.title ?? '',
        session ? DateUtils.formatDate(session.startTime) : '',
        '',
        '',
        '未检测',
        '缺勤'
      ];
      lines.push(row.map((value: string) => this.escapeCsv(value)).join(','));
    });

    const documentPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [`FaceCheck_考勤报表_${DateUtils.formatDate(Date.now())}.csv`];
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
