import { relationalStore } from '@kit.ArkData';
import { DatabaseManager } from './DatabaseManager';
import {
  AttendanceRecord,
  AttendanceRecordDraft,
  AttendanceStats,
  CheckInStatus
} from '../models/AttendanceModel';
import { Logger } from '../utils/Logger';

const TABLE_NAME: string = 'attendance_records';

/**
 * 签到记录数据访问对象
 */
export class AttendanceDao {
  private getStore(): relationalStore.RdbStore {
    return DatabaseManager.getInstance().getStore();
  }

  /**
   * 插入签到记录
   * 由于 (session_id, user_id) 唯一约束，重复签到会抛出异常
   */
  async insert(record: AttendanceRecordDraft): Promise<number> {
    const valueBucket: relationalStore.ValuesBucket = {
      'session_id': record.sessionId,
      'user_id': record.userId,
      'check_in_time': record.checkInTime,
      'compare_score': record.compareScore,
      'liveness_passed': record.livenessPassed ? 1 : 0,
      'status': record.status,
      'captured_image_path': record.capturedImagePath
    };

    try {
      const rowId = await this.getStore().insert(TABLE_NAME, valueBucket);
      Logger.info('签到记录插入成功, rowId: %{public}d', rowId.toString());
      return rowId;
    } catch (error) {
      Logger.error('插入签到记录失败: %{public}s', JSON.stringify(error));
      const caughtError = error as Error;
      throw new Error(caughtError.message);
    }
  }

  /**
   * 检查用户在某场次是否已签到
   */
  async hasCheckedIn(sessionId: number, userId: number): Promise<boolean> {
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('session_id', sessionId);
    predicates.equalTo('user_id', userId);

    try {
      const resultSet = await this.getStore().query(predicates);
      const exists = resultSet.rowCount > 0;
      resultSet.close();
      return exists;
    } catch (error) {
      Logger.error('检查签到状态失败: %{public}s', JSON.stringify(error));
      return false;
    }
  }

  /**
   * 查询某场次的所有签到记录（联表显示用户信息）
   */
  async getBySessionId(sessionId: number): Promise<AttendanceRecord[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('session_id', sessionId);
    predicates.orderByDesc('check_in_time');

    try {
      const resultSet = await this.getStore().query(predicates);
      const records: AttendanceRecord[] = [];
      while (resultSet.goToNextRow()) {
        records.push(this.mapResultSetToRecord(resultSet));
      }
      resultSet.close();
      return records;
    } catch (error) {
      Logger.error('查询场次签到记录失败: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 查询某用户的所有签到记录
   */
  async getByUserId(userId: number): Promise<AttendanceRecord[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('user_id', userId);
    predicates.orderByDesc('check_in_time');

    try {
      const resultSet = await this.getStore().query(predicates);
      const records: AttendanceRecord[] = [];
      while (resultSet.goToNextRow()) {
        records.push(this.mapResultSetToRecord(resultSet));
      }
      resultSet.close();
      return records;
    } catch (error) {
      Logger.error('查询用户签到记录失败: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 获取所有记录，按时间倒序
   */
  async getAll(): Promise<AttendanceRecord[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.orderByDesc('check_in_time');

    try {
      const resultSet = await this.getStore().query(predicates);
      const records: AttendanceRecord[] = [];
      while (resultSet.goToNextRow()) {
        records.push(this.mapResultSetToRecord(resultSet));
      }
      resultSet.close();
      return records;
    } catch (error) {
      Logger.error('查询所有签到记录失败: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 获取某场次签到统计
   *
   * 注意：ABSENT 状态的记录不计入 checkedIn；
   *       absentCount = totalUsers - checkedIn（始终保持一致）。
   */
  async getSessionStats(sessionId: number, totalUsers: number): Promise<AttendanceStats> {
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('session_id', sessionId);

    try {
      const resultSet = await this.getStore().query(predicates);
      let checkedIn = 0;
      let lateCount = 0;

      while (resultSet.goToNextRow()) {
        const status = resultSet.getLong(resultSet.getColumnIndex('status')) as CheckInStatus;
        if (status === CheckInStatus.ABSENT) {
          continue; // 缺勤记录不计入 "已签到"
        }
        checkedIn++;
        if (status === CheckInStatus.LATE) {
          lateCount++;
        }
      }
      resultSet.close();

      return {
        totalUsers: totalUsers,
        checkedIn: checkedIn,
        lateCount: lateCount,
        absentCount: totalUsers - checkedIn
      };
    } catch (error) {
      Logger.error('获取签到统计失败: %{public}s', JSON.stringify(error));
      return {
        totalUsers: totalUsers,
        checkedIn: 0,
        lateCount: 0,
        absentCount: totalUsers
      };
    }
  }

  /**
   * 获取最近的签到记录（首页展示用）
   */
  async getRecentRecords(limit: number): Promise<AttendanceRecord[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.orderByDesc('check_in_time');
    predicates.limitAs(limit);

    try {
      const resultSet = await this.getStore().query(predicates);
      const records: AttendanceRecord[] = [];
      while (resultSet.goToNextRow()) {
        records.push(this.mapResultSetToRecord(resultSet));
      }
      resultSet.close();
      return records;
    } catch (error) {
      Logger.error('查询最近签到记录失败: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  /**
   * 删除某场次的所有签到记录
   */
  async deleteBySessionId(sessionId: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('session_id', sessionId);

    try {
      await this.getStore().delete(predicates);
      Logger.info('场次签到记录删除成功, sessionId: %{public}d', sessionId.toString());
    } catch (error) {
      Logger.error('删除场次签到记录失败: %{public}s', JSON.stringify(error));
      const caughtError = error as Error;
      throw new Error(caughtError.message);
    }
  }

  /**
   * 将结果集行映射为 AttendanceRecord
   */
  private mapResultSetToRecord(resultSet: relationalStore.ResultSet): AttendanceRecord {
    try {
      return {
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        sessionId: resultSet.getLong(resultSet.getColumnIndex('session_id')),
        userId: resultSet.getLong(resultSet.getColumnIndex('user_id')),
        checkInTime: resultSet.getLong(resultSet.getColumnIndex('check_in_time')),
        compareScore: resultSet.getDouble(resultSet.getColumnIndex('compare_score')),
        livenessPassed: resultSet.getLong(resultSet.getColumnIndex('liveness_passed')) === 1,
        status: resultSet.getLong(resultSet.getColumnIndex('status')) as CheckInStatus,
        capturedImagePath: resultSet.getString(resultSet.getColumnIndex('captured_image_path'))
      };
    } catch (error) {
      const caughtError = error as Error;
      throw new Error(`签到记录解析失败: ${caughtError.message}`);
    }
  }
}
