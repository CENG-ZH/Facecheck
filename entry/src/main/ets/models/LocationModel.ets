/**
 * 地理围栏与签到设备定位模型。
 * 当前项目是 Pad 轮流刷脸模式，位置校验指当前签到设备位置。
 */
export interface LocationSnapshot {
  latitude: number;
  longitude: number;
  accuracy: number;
  timestamp: number;
}

export interface GeoFenceConfig {
  enableLocationCheck: boolean;
  locationName: string;
  latitude: number;
  longitude: number;
  radiusMeters: number;
  locationAccuracy: number;
}

export enum LocationCheckStatus {
  DISABLED = 'disabled',
  PASSED = 'passed',
  FAILED = 'failed',
  PERMISSION_DENIED = 'permission_denied',
  LOCATION_FAILED = 'location_failed'
}

export interface LocationCheckResult {
  status: LocationCheckStatus;
  passed: boolean;
  message: string;
  currentLocation?: LocationSnapshot;
  distanceMeters: number;
}

export interface LocationFetchResult {
  success: boolean;
  message: string;
  location?: LocationSnapshot;
  status: LocationCheckStatus;
}
