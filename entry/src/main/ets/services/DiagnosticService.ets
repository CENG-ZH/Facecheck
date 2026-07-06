import { fileIo, picker } from '@kit.CoreFileKit';
import { AppSettings, SettingsService } from './SettingsService';
import { OrganizationService } from './OrganizationService';
import { UserService } from './UserService';
import { DateUtils } from '../utils/DateUtils';

export interface DiagnosticSummary {
  generatedAt: number;
  appVersion: string;
  databaseVersion: string;
  settings: AppSettings;
  classCount: number;
  courseCount: number;
  userTotal: number;
  faceEnrolled: number;
}

export class DiagnosticService {
  private settingsService: SettingsService = SettingsService.getInstance();
  private organizationService: OrganizationService = new OrganizationService();
  private userService: UserService = new UserService();

  async buildSummary(): Promise<DiagnosticSummary> {
    const settings = this.settingsService.getSettings();
    const classes = await this.organizationService.getClasses();
    const courses = await this.organizationService.getCourses();
    const userStats = await this.userService.getUserStats();
    return {
      generatedAt: Date.now(),
      appVersion: '2.0.0-dev',
      databaseVersion: 'RDB v4',
      settings: settings,
      classCount: classes.length,
      courseCount: courses.length,
      userTotal: userStats.total,
      faceEnrolled: userStats.enrolled
    };
  }

  async exportDiagnosticText(context: Context): Promise<string> {
    const summary = await this.buildSummary();
    const lines: string[] = [
      'FaceCheck 诊断摘要',
      `生成时间: ${DateUtils.formatDate(summary.generatedAt)} ${DateUtils.formatTime(summary.generatedAt)}`,
      '',
      '[版本]',
      `应用版本: ${summary.appVersion}`,
      `数据库版本: ${summary.databaseVersion}`,
      '',
      '[能力]',
      'UI: ArkTS + ArkUI + PlanUI',
      '人脸: Core Vision Kit 检测与 1:1 比对',
      '活体: Vision Kit Interactive Liveness，可在设置页开启',
      '定位: Location Kit 前台即时定位，按场次地理围栏校验',
      '存储: ArkData RelationalStore + Preferences',
      '',
      '[当前设置]',
      `人脸匹配阈值: ${summary.settings.faceThreshold}%`,
      `活体检测: ${this.boolText(summary.settings.enableLiveness)}`,
      `迟到判定: ${summary.settings.lateMinutes} 分钟`,
      `新建场次默认位置校验: ${this.boolText(summary.settings.defaultLocationEnabled)}`,
      `默认围栏半径: ${summary.settings.defaultLocationRadius}m`,
      `定位超时: ${summary.settings.locationTimeoutSeconds}s`,
      '',
      '[数据规模]',
      `有效班级: ${summary.classCount}`,
      `有效课程: ${summary.courseCount}`,
      `有效人员: ${summary.userTotal}`,
      `已录入人脸: ${summary.faceEnrolled}`,
      '',
      '[隐私边界]',
      '诊断摘要只导出统计和配置，不导出姓名、学号、人脸照片或签到明细。'
    ];

    const documentPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [`FaceCheck_Diagnostic_${DateUtils.formatDate(Date.now())}.txt`];
    options.fileSuffixChoices = ['TXT 文件|.txt'];
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

  private boolText(value: boolean): string {
    return value ? '开启' : '关闭';
  }
}
