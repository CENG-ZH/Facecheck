import { preferences } from '@kit.ArkData';
import { Logger } from '../utils/Logger';

const PREFERENCES_NAME: string = 'facecheck_settings';

/**
 * 设置项键名常量
 */
const KEY_FACE_THRESHOLD: string = 'face_threshold';
const KEY_ENABLE_LIVENESS: string = 'enable_liveness';
const KEY_LATE_MINUTES: string = 'late_minutes';

/**
 * 应用设置数据
 */
export interface AppSettings {
  faceThreshold: number;     // 人脸匹配阈值 (0-100)
  enableLiveness: boolean;   // 是否启用活体检测
  lateMinutes: number;       // 迟到时间（分钟）
}

/**
 * 默认设置
 */
const DEFAULT_SETTINGS: AppSettings = {
  faceThreshold: 80,
  enableLiveness: false,
  lateMinutes: 15
};

/**
 * 设置服务
 * 使用 Preferences 持久化应用配置
 */
export class SettingsService {
  private static instance: SettingsService;
  private prefs: preferences.Preferences | null = null;
  private cachedSettings: AppSettings = {
    faceThreshold: DEFAULT_SETTINGS.faceThreshold,
    enableLiveness: DEFAULT_SETTINGS.enableLiveness,
    lateMinutes: DEFAULT_SETTINGS.lateMinutes
  };

  private constructor() {
  }

  public static getInstance(): SettingsService {
    if (!SettingsService.instance) {
      SettingsService.instance = new SettingsService();
    }
    return SettingsService.instance;
  }

  /**
   * 初始化设置服务
   */
  async initialize(context: Context): Promise<void> {
    try {
      this.prefs = await preferences.getPreferences(context, PREFERENCES_NAME);
      await this.loadAll();
      Logger.info('设置服务初始化成功');
    } catch (error) {
      Logger.error('设置服务初始化失败: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 加载所有设置
   */
  private async loadAll(): Promise<void> {
    if (!this.prefs) return;

    try {
      this.cachedSettings.faceThreshold = await this.prefs.get(
        KEY_FACE_THRESHOLD, DEFAULT_SETTINGS.faceThreshold
      ) as number;

      this.cachedSettings.enableLiveness = await this.prefs.get(
        KEY_ENABLE_LIVENESS, DEFAULT_SETTINGS.enableLiveness
      ) as boolean;

      this.cachedSettings.lateMinutes = await this.prefs.get(
        KEY_LATE_MINUTES, DEFAULT_SETTINGS.lateMinutes
      ) as number;
    } catch (error) {
      Logger.error('加载设置失败: %{public}s', JSON.stringify(error));
      this.cachedSettings = {
        faceThreshold: DEFAULT_SETTINGS.faceThreshold,
        enableLiveness: DEFAULT_SETTINGS.enableLiveness,
        lateMinutes: DEFAULT_SETTINGS.lateMinutes
      };
    }
  }

  /**
   * 获取所有设置（从缓存读取）
   */
  getSettings(): AppSettings {
    const settings: AppSettings = {
      faceThreshold: this.cachedSettings.faceThreshold,
      enableLiveness: this.cachedSettings.enableLiveness,
      lateMinutes: this.cachedSettings.lateMinutes
    };
    return settings;
  }

  /**
   * 获取人脸匹配阈值
   */
  getFaceThreshold(): number {
    return this.cachedSettings.faceThreshold;
  }

  /**
   * 获取人脸匹配阈值（0-1 范围，供比对使用）
   */
  getFaceThresholdNormalized(): number {
    return this.cachedSettings.faceThreshold / 100;
  }

  /**
   * 是否启用活体检测
   */
  isLivenessEnabled(): boolean {
    return this.cachedSettings.enableLiveness;
  }

  /**
   * 获取迟到时间（分钟）
   */
  getLateMinutes(): number {
    return this.cachedSettings.lateMinutes;
  }

  /**
   * 设置人脸匹配阈值
   */
  async setFaceThreshold(value: number): Promise<void> {
    // 阈值范围: 0-100，超出范围自动截断
    const clamped = Math.max(0, Math.min(100, Math.round(value)));
    this.cachedSettings.faceThreshold = clamped;
    await this.save(KEY_FACE_THRESHOLD, clamped);
  }

  /**
   * 设置是否启用活体检测
   */
  async setEnableLiveness(value: boolean): Promise<void> {
    this.cachedSettings.enableLiveness = value;
    await this.save(KEY_ENABLE_LIVENESS, value);
  }

  /**
   * 设置迟到时间
   */
  async setLateMinutes(value: number): Promise<void> {
    // 迟到时间范围: 1-1440 分钟，超出范围自动截断
    const clamped = Math.max(1, Math.min(1440, Math.round(value)));
    this.cachedSettings.lateMinutes = clamped;
    await this.save(KEY_LATE_MINUTES, clamped);
  }

  /**
   * 保存单个设置项
   */
  private async save(key: string, value: preferences.ValueType): Promise<void> {
    if (!this.prefs) return;

    try {
      await this.prefs.put(key, value);
      await this.prefs.flush();
    } catch (error) {
      Logger.error('保存设置失败: key=%{public}s, error=%{public}s', key, JSON.stringify(error));
    }
  }
}
