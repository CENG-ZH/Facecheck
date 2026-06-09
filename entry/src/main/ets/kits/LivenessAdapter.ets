import { interactiveLiveness } from '@kit.VisionKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { abilityAccessCtrl, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Logger } from '../utils/Logger';

/**
 * 活体检测结果
 */
export interface LivenessResult {
  passed: boolean;
  message: string;
  pixelMap?: image.PixelMap;
}

/**
 * 活体检测适配器
 * 封装 Vision Kit 的 interactiveLiveness 接口
 *
 * 使用场景：签到时防止照片翻拍/屏幕翻拍攻击
 * 官方推荐：适用于低危场景（考勤打卡、辅助登录、实名认证）
 *
 * 约束限制：
 * - 仅支持真机，不支持模拟器和预览器
 * - 需要相机权限（module.json5 中声明 ohos.permission.CAMERA）
 * - API 12+ 支持
 */
export class LivenessAdapter {
  private static readonly CAMERA_PERMISSION: Permissions = 'ohos.permission.CAMERA';
  private static readonly INTERACTIVE_LIVENESS_TYPE: number = 0;
  private static readonly SILENT_LIVENESS_TYPE: number = 1;
  private static readonly NOT_LIVENESS_TYPE: number = 2;
  private static isRunning: boolean = false;
  private static previousOrientation: window.Orientation = window.Orientation.AUTO_ROTATION_UNSPECIFIED;

  private static async requestCameraPermission(context: Context): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(
        context,
        [LivenessAdapter.CAMERA_PERMISSION]
      );
      const granted = result.authResults.length > 0 && result.authResults[0] === 0;
      Logger.info('活体检测相机权限结果: %{public}s', granted.toString());
      return granted;
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error('申请相机权限失败, code: %{public}s, msg: %{public}s',
        businessError.code?.toString() ?? 'unknown', businessError.message ?? 'unknown');
      return false;
    }
  }

  private static async setOrientation(context: Context, orientation: window.Orientation): Promise<void> {
    try {
      const appWindow = await window.getLastWindow(context);
      await appWindow.setPreferredOrientation(orientation);
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error('切换屏幕方向失败, code: %{public}s, msg: %{public}s',
        businessError.code?.toString() ?? 'unknown', businessError.message ?? 'unknown');
      throw new Error('无法切换活体检测所需的竖屏方向');
    }
  }

  private static async rememberAndLockPortrait(context: Context): Promise<void> {
    try {
      const appWindow = await window.getLastWindow(context);
      LivenessAdapter.previousOrientation = appWindow.getPreferredOrientation();
      await appWindow.setPreferredOrientation(window.Orientation.PORTRAIT);
      Logger.info('活体检测锁定竖屏，原方向: %{public}s',
        LivenessAdapter.previousOrientation.toString());
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error('记录并切换屏幕方向失败, code: %{public}s, msg: %{public}s',
        businessError.code?.toString() ?? 'unknown', businessError.message ?? 'unknown');
      throw new Error('无法切换活体检测所需的竖屏方向');
    }
  }

  private static async restoreOrientation(context: Context): Promise<void> {
    try {
      await LivenessAdapter.setOrientation(context, LivenessAdapter.previousOrientation);
      Logger.info('活体检测已恢复进入前方向: %{public}s',
        LivenessAdapter.previousOrientation.toString());
    } catch (error) {
      Logger.warn('恢复进入前屏幕方向失败: %{public}s', JSON.stringify(error));
    }
  }

  private static getErrorMessage(code: number | undefined): string {
    if (code === 1008302000) {
      return '活体检测初始化失败';
    }
    if (code === 1008302001) {
      return '活体检测超时，请重试';
    }
    if (code === 1008302002) {
      return '活体动作冲突，请重新检测';
    }
    if (code === 1008302003) {
      return '活体动作不连续，请重新检测';
    }
    if (code === 1008302004) {
      return '活体检测未完成，请重试';
    }
    return '活体检测失败，请重试';
  }

  /**
   * 拉起系统活体检测页面。
   * 此接口只表示页面跳转是否成功，检测结果需在业务页面重新显示后获取。
   */
  static async startLivenessDetection(context: Context): Promise<boolean> {
    if (LivenessAdapter.isRunning) {
      Logger.warn('活体检测正在进行，忽略重复启动');
      return false;
    }

    LivenessAdapter.isRunning = true;
    try {
      const permissionGranted = await LivenessAdapter.requestCameraPermission(context);
      if (!permissionGranted) {
        LivenessAdapter.isRunning = false;
        return false;
      }

      await LivenessAdapter.rememberAndLockPortrait(context);

      const config: interactiveLiveness.InteractiveLivenessConfig = {
        actionsNum: interactiveLiveness.ActionsNumber.THREE_ACTION,
        isSilentMode: interactiveLiveness.DetectionMode.INTERACTIVE_MODE,
        routeMode: interactiveLiveness.RouteRedirectionMode.BACK_MODE,
        speechSwitch: true
      };

      Logger.info('启动活体检测页面...');
      const started = await interactiveLiveness.startLivenessDetection(config);
      Logger.info('活体检测页面跳转结果: %{public}s', started.toString());
      if (!started) {
        LivenessAdapter.isRunning = false;
        await LivenessAdapter.restoreOrientation(context);
      }
      return started;
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error('活体检测页面启动失败, code: %{public}s, msg: %{public}s',
        businessError.code?.toString() ?? 'unknown', businessError.message ?? 'unknown');
      LivenessAdapter.isRunning = false;
      await LivenessAdapter.restoreOrientation(context);
      return false;
    }
  }

  /**
   * 页面从活体检测控件返回后获取结果。
   * 直接返回官方 mPixelMap，调用方在 finally 中负责释放。
   */
  static async getLivenessResult(context: Context): Promise<LivenessResult> {
    try {
      Logger.info('开始获取活体检测结果...');
      const result = await interactiveLiveness.getInteractiveLivenessResult();
      const livenessType = Number(result.livenessType);
      const passed = livenessType === LivenessAdapter.INTERACTIVE_LIVENESS_TYPE ||
        livenessType === LivenessAdapter.SILENT_LIVENESS_TYPE;
      Logger.info('活体检测结果: type=%{public}s, passed=%{public}s, hasImage=%{public}s',
        livenessType.toString(),
        passed.toString(),
        (result.mPixelMap !== undefined).toString());

      if (livenessType === LivenessAdapter.NOT_LIVENESS_TYPE) {
        return {
          passed: false,
          message: '未通过活体检测'
        };
      }

      if (!passed) {
        return {
          passed: false,
          message: `活体检测返回未知结果（类型 ${livenessType}）`
        };
      }

      return {
        passed: true,
        message: '活体检测通过',
        pixelMap: result.mPixelMap  // 直接返回原始 PixelMap，由调用方在 finally 中释放
      };
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.error('获取活体检测结果失败, code: %{public}s, msg: %{public}s',
        businessError.code?.toString() ?? 'unknown', businessError.message ?? 'unknown');
      return {
        passed: false,
        message: LivenessAdapter.getErrorMessage(businessError.code)
      };
    } finally {
      LivenessAdapter.isRunning = false;
      await LivenessAdapter.restoreOrientation(context);
    }
  }
}
