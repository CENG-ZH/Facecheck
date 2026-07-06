import { relationalStore } from '@kit.ArkData';
import { DatabaseManager } from './DatabaseManager';
import {
  CheckInAttempt,
  CheckInAttemptDraft
} from '../models/CheckInAttemptModel';
import { Logger } from '../utils/Logger';

const TABLE_NAME: string = 'check_in_attempts';

export class CheckInAttemptDao {
  private getStore(): relationalStore.RdbStore {
    return DatabaseManager.getInstance().getStore();
  }

  async insert(attempt: CheckInAttemptDraft): Promise<number> {
    const now = Date.now();
    const valueBucket: relationalStore.ValuesBucket = {
      'session_id': attempt.sessionId,
      'user_id': attempt.userId,
      'attempt_time': attempt.attemptTime,
      'stage': attempt.stage,
      'success': attempt.success ? 1 : 0,
      'fail_reason': attempt.failReason,
      'compare_score': attempt.compareScore ?? 0,
      'liveness_passed': attempt.livenessPassed === true ? 1 : 0,
      'location_passed': attempt.locationPassed === true ? 1 : 0,
      'distance_meters': attempt.distanceMeters ?? 0,
      'created_at': now
    };

    try {
      const rowId = await this.getStore().insert(TABLE_NAME, valueBucket);
      Logger.info('签到尝试记录插入成功, rowId: %{public}s', rowId.toString());
      return rowId;
    } catch (error) {
      Logger.error('插入签到尝试记录失败: %{public}s', JSON.stringify(error));
      const caughtError = error as Error;
      throw new Error(caughtError.message);
    }
  }

  async getRecentBySession(sessionId: number, limit: number = 30): Promise<CheckInAttempt[]> {
    const predicates = new relationalStore.RdbPredicates(TABLE_NAME);
    predicates.equalTo('session_id', sessionId);
    predicates.orderByDesc('attempt_time');
    predicates.limitAs(limit);

    try {
      const resultSet = await this.getStore().query(predicates);
      const attempts: CheckInAttempt[] = [];
      try {
        while (resultSet.goToNextRow()) {
          attempts.push(this.mapResultSetToAttempt(resultSet));
        }
      } finally {
        resultSet.close();
      }
      return attempts;
    } catch (error) {
      Logger.error('查询签到尝试记录失败: %{public}s', JSON.stringify(error));
      return [];
    }
  }

  private mapResultSetToAttempt(resultSet: relationalStore.ResultSet): CheckInAttempt {
    try {
      return {
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        sessionId: resultSet.getLong(resultSet.getColumnIndex('session_id')),
        userId: resultSet.getLong(resultSet.getColumnIndex('user_id')),
        attemptTime: resultSet.getLong(resultSet.getColumnIndex('attempt_time')),
        stage: resultSet.getString(resultSet.getColumnIndex('stage')),
        success: resultSet.getLong(resultSet.getColumnIndex('success')) === 1,
        failReason: resultSet.getString(resultSet.getColumnIndex('fail_reason')),
        compareScore: resultSet.getDouble(resultSet.getColumnIndex('compare_score')),
        livenessPassed: resultSet.getLong(resultSet.getColumnIndex('liveness_passed')) === 1,
        locationPassed: resultSet.getLong(resultSet.getColumnIndex('location_passed')) === 1,
        distanceMeters: resultSet.getDouble(resultSet.getColumnIndex('distance_meters')),
        createdAt: resultSet.getLong(resultSet.getColumnIndex('created_at'))
      };
    } catch (error) {
      const caughtError = error as Error;
      throw new Error(`签到尝试记录解析失败: ${caughtError.message}`);
    }
  }
}
