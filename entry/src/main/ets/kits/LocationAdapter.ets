import { abilityAccessCtrl, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { geoLocationManager } from '@kit.LocationKit';
import {
  LocationCheckStatus,
  LocationFetchResult,
  LocationSnapshot
} from '../models/LocationModel';
import { Logger } from '../utils/Logger';

const LOCATION_PERMISSIONS: Permissions[] = [
  'ohos.permission.APPROXIMATELY_LOCATION',
  'ohos.permission.LOCATION'
];
const DEFAULT_TIMEOUT_MS: number = 10000;

/**
 * Location Kit 适配层。
 * 当前只做前台即时定位，不做后台围栏和持续轨迹。
 */
export class LocationAdapter {
  static async getCurrentLocation(
    context: Context,
    timeoutMs: number = DEFAULT_TIMEOUT_MS
  ): Promise<LocationFetchResult> {
    const granted = await LocationAdapter.requestPermission(context);
    if (!granted) {
      return {
        success: false,
        message: '位置权限未授权，无法进行地理围栏校验',
        status: LocationCheckStatus.PERMISSION_DENIED
      };
    }

    try {
      const position = await geoLocationManager.getCurrentLocation({
        priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
        scenario: geoLocationManager.LocationRequestScenario.UNSET,
        timeoutMs: timeoutMs
      });

      const snapshot: LocationSnapshot = {
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy ?? 0,
        timestamp: Date.now()
      };
      Logger.info('定位成功: lat=%{public}s, lon=%{public}s, accuracy=%{public}s',
        snapshot.latitude.toString(), snapshot.longitude.toString(), snapshot.accuracy.toString());
      return {
        success: true,
        message: '定位成功',
        location: snapshot,
        status: LocationCheckStatus.PASSED
      };
    } catch (error) {
      Logger.error('定位失败: %{public}s', JSON.stringify(error));
      return {
        success: false,
        message: '定位失败，请确认设备定位服务已开启后重试',
        status: LocationCheckStatus.LOCATION_FAILED
      };
    }
  }

  private static async requestPermission(context: Context): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(
        context,
        LOCATION_PERMISSIONS
      );
      let granted = result.authResults.length === LOCATION_PERMISSIONS.length;
      for (let index = 0; index < result.authResults.length; index++) {
        if (result.authResults[index] !== 0) {
          granted = false;
        }
      }
      Logger.info('位置权限结果: %{public}s', granted.toString());
      return granted;
    } catch (error) {
      const businessError = error as BusinessError;
      Logger.warn('申请位置权限失败, code: %{public}s, msg: %{public}s',
        businessError.code?.toString() ?? 'unknown', businessError.message ?? 'unknown');
      return false;
    }
  }
}
