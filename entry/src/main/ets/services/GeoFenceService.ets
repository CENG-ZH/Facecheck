import {
  GeoFenceConfig,
  LocationCheckResult,
  LocationCheckStatus,
  LocationSnapshot
} from '../models/LocationModel';

const EARTH_RADIUS_METERS: number = 6371000;

/**
 * 地理围栏业务服务：负责距离计算和围栏结果判定。
 */
export class GeoFenceService {
  static calculateDistanceMeters(from: LocationSnapshot, to: LocationSnapshot): number {
    const fromLat = GeoFenceService.toRadians(from.latitude);
    const toLat = GeoFenceService.toRadians(to.latitude);
    const deltaLat = GeoFenceService.toRadians(to.latitude - from.latitude);
    const deltaLon = GeoFenceService.toRadians(to.longitude - from.longitude);

    const a = Math.sin(deltaLat / 2) * Math.sin(deltaLat / 2) +
      Math.cos(fromLat) * Math.cos(toLat) *
      Math.sin(deltaLon / 2) * Math.sin(deltaLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return Math.round(EARTH_RADIUS_METERS * c);
  }

  static check(config: GeoFenceConfig, currentLocation: LocationSnapshot): LocationCheckResult {
    if (!config.enableLocationCheck) {
      return {
        status: LocationCheckStatus.DISABLED,
        passed: true,
        message: '本场未启用位置校验',
        currentLocation: currentLocation,
        distanceMeters: 0
      };
    }

    const center: LocationSnapshot = {
      latitude: config.latitude,
      longitude: config.longitude,
      accuracy: config.locationAccuracy,
      timestamp: currentLocation.timestamp
    };
    const distance = GeoFenceService.calculateDistanceMeters(center, currentLocation);
    const radius = Math.max(1, Math.round(config.radiusMeters));
    const passed = distance <= radius;
    const place = config.locationName.trim() === '' ? '签到点' : config.locationName.trim();

    return {
      status: passed ? LocationCheckStatus.PASSED : LocationCheckStatus.FAILED,
      passed: passed,
      message: passed
        ? `位置校验通过，当前设备距${place}约 ${distance} 米`
        : `当前位置距${place}约 ${distance} 米，超出允许范围 ${radius} 米`,
      currentLocation: currentLocation,
      distanceMeters: distance
    };
  }

  private static toRadians(value: number): number {
    return value * Math.PI / 180;
  }
}
