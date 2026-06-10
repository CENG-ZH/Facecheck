import { faceDetector, faceComparator } from '@kit.CoreVisionKit';
import { image } from '@kit.ImageKit';
import { FaceDetectionResult, FaceCompareResult } from '../models/AttendanceModel';
import { Logger } from '../utils/Logger';

/**
 * 人脸视觉适配器
 * 封装 Core Vision Kit 的 faceDetector 和 faceComparator
 *
 * 使用说明：
 * 1. 调用 init() 初始化引擎（在页面 aboutToAppear 中）
 * 2. 调用 detect() / compare() 进行检测/比对
 * 3. 调用 release() 释放资源（在页面 aboutToDisappear 中）
 *
 * 约束限制：
 * - 仅支持真机，不支持模拟器
 * - faceComparator 仅支持 1:1 比对，不支持并发调用
 * - 输入 PixelMap 色彩格式需满足 RGBA_8888
 */
export class FaceVisionAdapter {
  private static isDetectorInitialized: boolean = false;
  private static isComparatorInitialized: boolean = false;
  private static initPromise: Promise<void> | null = null;

  /**
   * 初始化人脸检测引擎
   */
  static async initDetector(): Promise<void> {
    if (FaceVisionAdapter.isDetectorInitialized) {
      return;
    }
    try {
      await faceDetector.init();
      FaceVisionAdapter.isDetectorInitialized = true;
      Logger.info('人脸检测引擎初始化成功');
    } catch (error) {
      Logger.error('人脸检测引擎初始化失败: %{public}s', JSON.stringify(error));
      const caughtError = error as Error;
      throw new Error(caughtError.message);
    }
  }

  /**
   * 初始化人脸比对引擎
   */
  static async initComparator(): Promise<void> {
    if (FaceVisionAdapter.isComparatorInitialized) {
      return;
    }
    try {
      await faceComparator.init();
      FaceVisionAdapter.isComparatorInitialized = true;
      Logger.info('人脸比对引擎初始化成功');
    } catch (error) {
      Logger.error('人脸比对引擎初始化失败: %{public}s', JSON.stringify(error));
      const caughtError = error as Error;
      throw new Error(caughtError.message);
    }
  }

  /**
   * 初始化所有引擎（检测 + 比对）
   */
  static async initAll(): Promise<void> {
    if (FaceVisionAdapter.initPromise !== null) {
      return FaceVisionAdapter.initPromise;
    }
    FaceVisionAdapter.initPromise = (async () => {
      await FaceVisionAdapter.initDetector();
      await FaceVisionAdapter.initComparator();
    })();
    return FaceVisionAdapter.initPromise;
  }

  /**
   * 检测人脸
   * @param pixelMap 待检测的图片
   * @returns 检测结果：是否有人脸、人脸数量、是否正面
   */
  static async detect(pixelMap: image.PixelMap): Promise<FaceDetectionResult> {
    try {
      if (!FaceVisionAdapter.isDetectorInitialized) {
        await FaceVisionAdapter.initDetector();
      }

      const visionInfo: faceDetector.VisionInfo = {
        pixelMap: pixelMap
      };
      const faces = await faceDetector.detect(visionInfo);

      if (!faces || faces.length === 0) {
        return {
          hasFace: false,
          faceCount: 0,
          message: '未检测到人脸，请调整位置后重试',
          isFrontal: false
        };
      }

      if (faces.length > 1) {
        return {
          hasFace: true,
          faceCount: faces.length,
          message: `检测到 ${faces.length} 张人脸，请确保画面中只有一人`,
          isFrontal: false
        };
      }

      // 单张人脸 - 检查姿态（如果 API 提供角度信息）
      const face = faces[0];
      let isFrontal = true;
      let message = '检测到1张正面人脸';

      // 检查人脸姿态角度
      // 阈值：偏转超过 30° 视为非正面
      if (Math.abs(face.pose.yaw) > 30) {
        isFrontal = false;
        message = '人脸偏转角度过大，请正面面对摄像头';
      }
      if (Math.abs(face.pose.pitch) > 30) {
        isFrontal = false;
        message = '人脸俯仰角度过大，请正面面对摄像头';
      }

      Logger.info('人脸检测: count=%{public}d, frontal=%{public}s, bounds=%{public}s',
        faces.length.toString(),
        isFrontal.toString(),
        JSON.stringify(face.rect));

      return {
        hasFace: true,
        faceCount: 1,
        message: message,
        isFrontal: isFrontal
      };
    } catch (error) {
      Logger.error('人脸检测失败: %{public}s', JSON.stringify(error));
      return {
        hasFace: false,
        faceCount: 0,
        message: '人脸检测失败，请重试',
        isFrontal: false
      };
    }
  }

  /**
   * 人脸比对 (1:1)
   * 比较注册照片和现场拍照中的人脸是否为同一人
   *
   * 注意：不要写死阈值！先记录官方返回的 isSamePerson 和 similarity，
   * 再通过实机样本确定合适的阈值。
   *
   * @param registeredPixelMap 已注册的人脸照片
   * @param capturedPixelMap 现场拍摄的照片
   * @returns 比对结果：是否匹配、相似度分数
   */
  static async compare(
    registeredPixelMap: image.PixelMap,
    capturedPixelMap: image.PixelMap
  ): Promise<FaceCompareResult> {
    try {
      if (!FaceVisionAdapter.isComparatorInitialized) {
        await FaceVisionAdapter.initComparator();
      }

      const visionInfo1: faceComparator.VisionInfo = {
        pixelMap: registeredPixelMap
      };
      const visionInfo2: faceComparator.VisionInfo = {
        pixelMap: capturedPixelMap
      };

      const result: faceComparator.FaceCompareResult =
        await faceComparator.compareFaces(visionInfo1, visionInfo2);

      Logger.info('人脸比对: isSamePerson=%{public}s, similarity=%{public}s',
        String(result.isSamePerson),
        String(result.similarity));

      // 记录官方返回的原始结果，不自行判断阈值
      return {
        isMatch: result.isSamePerson,
        score: result.similarity,
        message: result.isSamePerson
          ? `人脸匹配成功 (相似度: ${(result.similarity * 100).toFixed(1)}%)`
          : `人脸不匹配 (相似度: ${(result.similarity * 100).toFixed(1)}%)`
      };
    } catch (error) {
      Logger.error('人脸比对失败: %{public}s', JSON.stringify(error));
      return {
        isMatch: false,
        score: 0,
        message: '人脸比对失败，请重试'
      };
    } finally {
      try {
        registeredPixelMap.release();
      } catch (releaseError) {
        Logger.warn('释放注册照片 PixelMap 失败: %{public}s', JSON.stringify(releaseError));
      }
      try {
        capturedPixelMap.release();
      } catch (releaseError) {
        Logger.warn('释放现场照片 PixelMap 失败: %{public}s', JSON.stringify(releaseError));
      }
    }
  }

  /**
   * 释放人脸检测引擎资源
   */
  static async releaseDetector(): Promise<void> {
    if (FaceVisionAdapter.isDetectorInitialized) {
      try {
        await faceDetector.release();
        FaceVisionAdapter.isDetectorInitialized = false;
        Logger.info('人脸检测引擎已释放');
      } catch (error) {
        Logger.error('释放人脸检测引擎失败: %{public}s', JSON.stringify(error));
      }
    }
  }

  /**
   * 释放人脸比对引擎资源
   */
  static async releaseComparator(): Promise<void> {
    if (FaceVisionAdapter.isComparatorInitialized) {
      try {
        await faceComparator.release();
        FaceVisionAdapter.isComparatorInitialized = false;
        Logger.info('人脸比对引擎已释放');
      } catch (error) {
        Logger.error('释放人脸比对引擎失败: %{public}s', JSON.stringify(error));
      }
    }
  }

  /**
   * 释放所有引擎资源
   */
  static async releaseAll(): Promise<void> {
    await FaceVisionAdapter.releaseDetector();
    await FaceVisionAdapter.releaseComparator();
  }
}
