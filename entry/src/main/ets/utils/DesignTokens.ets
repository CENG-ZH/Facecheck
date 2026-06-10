/**
 * DesignTokens.ets — FaceCheck 全局设计令牌
 * 所有颜色/阴影/圆角/间距常量集中管理，确保多页面一致性。
 * 使用方法：在 .ets 文件中 import { Colors, Shadows, Radius, Spacing } from '../utils/DesignTokens'
 */
export class Colors {
  // 背景
  static readonly bg: string = '#F5F7F9';          // 页面背景（微暖灰白）
  static readonly card: string = '#FFFFFF';           // 卡片背景（纯白）
  static readonly inputBg: string = '#F1F3F5';        // 输入框背景

  // 品牌 & 状态
  static readonly primary: string = '#1677FF';        // 主蓝（HMS 标准蓝）
  static readonly success: string = '#00B42A';        // 成功（鲜绿）
  static readonly warning: string = '#FF7D00';         // 迟到/警告（橙）
  static readonly danger: string = '#F53F3F';          // 失败/危险（红）

  // 文字
  static readonly textPrimary: string = '#1D2129';     // 主文字（近黑）
  static readonly textSecondary: string = '#4E5969';   // 次要文字
  static readonly textTertiary: string = '#86909C';   // 辅助/占位文字

  // 通用
  static readonly white: string = '#FFFFFF';            // 白色（文字/图标/背景）

  // 边框/分割
  static readonly border: string = '#E5E6EB';
  static readonly borderLight: string = '#F2F3F5';

  // 品牌扩展
  static readonly primaryBg: string = '#EAF4FF';       // 主色浅背景（选中态）
  static readonly primaryLight: string = '#E6F7FF';    // 品牌超浅底
  static readonly disabled: string = '#B8C1CC';        // 禁用态

  // 状态背景（浅色）
  static readonly successBg: string = '#E6FFF2';      // 成功状态浅背景
  static readonly successBgAlt: string = '#F1F7F3';   // 成功状态极浅背景
  static readonly warningBg: string = '#FFF7E6';      // 迟到状态浅背景
  static readonly dangerBg: string = '#FFF1F0';       // 失败状态浅背景
  static readonly dangerDark: string = '#C62828';     // 深红错误文字

  // 滚动条
  static readonly scrollbar: string = '#AAB4C0';      // 滚动条颜色
}

export class Shadows {
  static readonly card: ShadowOptions = {
    radius: 15,
    color: '#1A000000',
    offsetY: 6
  };
  static readonly button: ShadowOptions = {
    radius: 8,
    color: '#20007DFF',
    offsetY: 3
  };
  static readonly buttonPressed: ShadowOptions = {
    radius: 20,
    color: '#30007DFF',
    offsetY: 6
  };
  static readonly danger: ShadowOptions = {
    radius: 5,
    color: '#20F53B3F',
    offsetY: 2
  };
}

export class Radius {
  static readonly card: number = 12;
  static readonly button: number = 6;
  static readonly pill: number = 100;
  static readonly input: number = 6;
}

export class Spacing {
  static readonly xs: number = 4;
  static readonly sm: number = 8;
  static readonly base: number = 12;
  static readonly card: number = 16;
  static readonly lg: number = 20;
}
