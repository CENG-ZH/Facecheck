import { relationalStore } from '@kit.ArkData';
import { Logger } from '../utils/Logger';

const DB_NAME: string = 'facecheck.db';
const DB_VERSION: number = 4;

/**
 * 数据库管理器 - 单例模式
 * 管理 relationalStore 的创建、升级和访问
 */
export class DatabaseManager {
  private static instance: DatabaseManager;
  private rdbStore: relationalStore.RdbStore | null = null;

  private constructor() {
  }

  public static getInstance(): DatabaseManager {
    if (!DatabaseManager.instance) {
      DatabaseManager.instance = new DatabaseManager();
    }
    return DatabaseManager.instance;
  }

  /**
   * 初始化数据库
   */
  async initialize(context: Context): Promise<void> {
    if (this.rdbStore !== null) {
      return;
    }

    const storeConfig: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    try {
      this.rdbStore = await relationalStore.getRdbStore(context, storeConfig);
      await this.createTables();
      await this.migrateLegacyData();
      this.rdbStore.version = DB_VERSION;
      Logger.info('数据库初始化成功');
    } catch (error) {
      Logger.error('数据库初始化失败: %{public}s', JSON.stringify(error));
      const caughtError = error as Error;
      throw new Error(caughtError.message);
    }
  }

  /**
   * 获取数据库实例
   */
  getStore(): relationalStore.RdbStore {
    if (!this.rdbStore) {
      throw new Error('数据库尚未初始化，请先调用 initialize()');
    }
    return this.rdbStore;
  }

  /**
   * 创建数据表
   */
  private async createTables(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }

    // 用户表。class_name 保留用于兼容旧版本，class_id 是新关系模型的主字段。
    const createUsersTable = `
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_no TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        class_name TEXT NOT NULL DEFAULT '',
        class_id INTEGER NOT NULL DEFAULT 0,
        face_image_path TEXT DEFAULT '',
        face_enrolled INTEGER DEFAULT 0,
        status INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    `;

    const createClassesTable = `
      CREATE TABLE IF NOT EXISTS admin_classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        grade TEXT NOT NULL DEFAULT '',
        major TEXT NOT NULL DEFAULT '',
        status INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    `;

    const createCoursesTable = `
      CREATE TABLE IF NOT EXISTS courses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        status INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    `;

    const createEnrollmentsTable = `
      CREATE TABLE IF NOT EXISTS course_enrollments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        course_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        status INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        UNIQUE(course_id, user_id)
      )
    `;

    const createSessionsTable = `
      CREATE TABLE IF NOT EXISTS attendance_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        course_id INTEGER NOT NULL DEFAULT 0,
        start_time INTEGER NOT NULL,
        late_time INTEGER DEFAULT 0,
        end_time INTEGER DEFAULT 0,
        status INTEGER DEFAULT 0,
        enable_location_check INTEGER NOT NULL DEFAULT 0,
        location_name TEXT DEFAULT '',
        latitude REAL DEFAULT 0,
        longitude REAL DEFAULT 0,
        radius_meters INTEGER NOT NULL DEFAULT 100,
        location_accuracy REAL DEFAULT 0
      )
    `;

    const createSessionMembersTable = `
      CREATE TABLE IF NOT EXISTS session_members (
        session_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        class_id INTEGER NOT NULL DEFAULT 0,
        course_id INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        PRIMARY KEY(session_id, user_id)
      )
    `;

    const createRecordsTable = `
      CREATE TABLE IF NOT EXISTS attendance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        check_in_time INTEGER NOT NULL,
        compare_score REAL DEFAULT 0,
        liveness_passed INTEGER DEFAULT 0,
        status INTEGER DEFAULT 0,
        captured_image_path TEXT DEFAULT '',
        check_latitude REAL DEFAULT 0,
        check_longitude REAL DEFAULT 0,
        check_location_accuracy REAL DEFAULT 0,
        distance_meters REAL DEFAULT 0,
        location_passed INTEGER NOT NULL DEFAULT 1,
        location_fail_reason TEXT DEFAULT '',
        UNIQUE(session_id, user_id)
      )
    `;

    const createAttemptsTable = `
      CREATE TABLE IF NOT EXISTS check_in_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        user_id INTEGER DEFAULT 0,
        attempt_time INTEGER NOT NULL,
        stage TEXT NOT NULL DEFAULT '',
        success INTEGER NOT NULL DEFAULT 0,
        fail_reason TEXT DEFAULT '',
        compare_score REAL DEFAULT 0,
        liveness_passed INTEGER DEFAULT 0,
        location_passed INTEGER DEFAULT 0,
        distance_meters REAL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    `;
    const createRecordSessionIndex =
      'CREATE INDEX IF NOT EXISTS idx_records_session_time ON attendance_records(session_id, check_in_time DESC)';
    const createRecordUserIndex =
      'CREATE INDEX IF NOT EXISTS idx_records_user_time ON attendance_records(user_id, check_in_time DESC)';
    const createSessionStatusIndex =
      'CREATE INDEX IF NOT EXISTS idx_sessions_status_start ON attendance_sessions(status, start_time DESC)';
    const createAttemptSessionIndex =
      'CREATE INDEX IF NOT EXISTS idx_attempts_session_time ON check_in_attempts(session_id, attempt_time DESC)';
    const createAttemptUserIndex =
      'CREATE INDEX IF NOT EXISTS idx_attempts_user_time ON check_in_attempts(user_id, attempt_time DESC)';
    try {
      await this.rdbStore.executeSql(createUsersTable);
      await this.rdbStore.executeSql(createClassesTable);
      await this.rdbStore.executeSql(createCoursesTable);
      await this.rdbStore.executeSql(createEnrollmentsTable);
      await this.rdbStore.executeSql(createSessionsTable);
      await this.rdbStore.executeSql(createSessionMembersTable);
      await this.rdbStore.executeSql(createRecordsTable);
      await this.rdbStore.executeSql(createAttemptsTable);
      await this.rdbStore.executeSql(createRecordSessionIndex);
      await this.rdbStore.executeSql(createRecordUserIndex);
      await this.rdbStore.executeSql(createSessionStatusIndex);
      await this.rdbStore.executeSql(createAttemptSessionIndex);
      await this.rdbStore.executeSql(createAttemptUserIndex);
      Logger.info('数据表创建成功');
    } catch (error) {
      Logger.error('数据表创建失败: %{public}s', JSON.stringify(error));
      const caughtError = error as Error;
      throw new Error(caughtError.message);
    }
  }

  private async addColumnIfMissing(sql: string): Promise<void> {
    if (!this.rdbStore) {
      return;
    }
    try {
      await this.rdbStore.executeSql(sql);
    } catch (error) {
      Logger.info('数据库字段已存在，跳过迁移: %{public}s', sql);
    }
  }

  /**
   * v2/v3 -> v4 无损迁移。旧数据归入默认课程，并补齐位置校验字段。
   */
  private async migrateLegacyData(): Promise<void> {
    if (!this.rdbStore) {
      return;
    }

    await this.addColumnIfMissing('ALTER TABLE users ADD COLUMN class_id INTEGER NOT NULL DEFAULT 0');
    await this.addColumnIfMissing('ALTER TABLE users ADD COLUMN status INTEGER NOT NULL DEFAULT 1');
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_sessions ADD COLUMN course_id INTEGER NOT NULL DEFAULT 0'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_sessions ADD COLUMN enable_location_check INTEGER NOT NULL DEFAULT 0'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_sessions ADD COLUMN location_name TEXT DEFAULT \'\''
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_sessions ADD COLUMN latitude REAL DEFAULT 0'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_sessions ADD COLUMN longitude REAL DEFAULT 0'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_sessions ADD COLUMN radius_meters INTEGER NOT NULL DEFAULT 100'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_sessions ADD COLUMN location_accuracy REAL DEFAULT 0'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_records ADD COLUMN check_latitude REAL DEFAULT 0'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_records ADD COLUMN check_longitude REAL DEFAULT 0'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_records ADD COLUMN check_location_accuracy REAL DEFAULT 0'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_records ADD COLUMN distance_meters REAL DEFAULT 0'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_records ADD COLUMN location_passed INTEGER NOT NULL DEFAULT 1'
    );
    await this.addColumnIfMissing(
      'ALTER TABLE attendance_records ADD COLUMN location_fail_reason TEXT DEFAULT \'\''
    );

    const now = Date.now();
    try {
      this.rdbStore.beginTransaction();
      await this.rdbStore.executeSql(
        `INSERT OR IGNORE INTO admin_classes(name, grade, major, status, created_at, updated_at)
         SELECT DISTINCT
           CASE WHEN TRIM(class_name) = '' THEN '未分班' ELSE TRIM(class_name) END,
           '', '', 1, ?, ?
         FROM users`,
        [now, now]
      );
      await this.rdbStore.executeSql(
        `INSERT OR IGNORE INTO admin_classes(name, grade, major, status, created_at, updated_at)
         VALUES('未分班', '', '', 1, ?, ?)`,
        [now, now]
      );
      await this.rdbStore.executeSql(
        `UPDATE users
         SET class_id = (
           SELECT id FROM admin_classes
           WHERE name = CASE WHEN TRIM(users.class_name) = '' THEN '未分班' ELSE TRIM(users.class_name) END
           LIMIT 1
         )
         WHERE class_id = 0`
      );
      await this.rdbStore.executeSql(
        `UPDATE users
         SET class_name = (
           SELECT name FROM admin_classes WHERE id = users.class_id LIMIT 1
         )
         WHERE class_name = ''`
      );
      await this.rdbStore.executeSql(
        `INSERT OR IGNORE INTO courses(code, name, status, created_at, updated_at)
         VALUES('DEFAULT', '鸿蒙应用开发', 1, ?, ?)`,
        [now, now]
      );
      await this.rdbStore.executeSql(
        `INSERT OR IGNORE INTO course_enrollments(course_id, user_id, status, created_at)
         SELECT (SELECT id FROM courses WHERE code = 'DEFAULT' LIMIT 1), id, 1, ?
         FROM users`,
        [now]
      );
      await this.rdbStore.executeSql(
        `UPDATE attendance_sessions
         SET course_id = (SELECT id FROM courses WHERE code = 'DEFAULT' LIMIT 1)
         WHERE course_id = 0`
      );
      await this.rdbStore.executeSql(
        `INSERT OR IGNORE INTO session_members(session_id, user_id, class_id, course_id, created_at)
         SELECT s.id, u.id, u.class_id, s.course_id, s.start_time
         FROM attendance_sessions s
         CROSS JOIN users u`
      );
      await this.rdbStore.executeSql(
        'CREATE INDEX IF NOT EXISTS idx_users_class_status ON users(class_id, status, student_no)'
      );
      await this.rdbStore.executeSql(
        'CREATE INDEX IF NOT EXISTS idx_enrollment_course_status ON course_enrollments(course_id, status)'
      );
      await this.rdbStore.executeSql(
        'CREATE INDEX IF NOT EXISTS idx_session_members_session ON session_members(session_id, user_id)'
      );
      await this.rdbStore.executeSql(
        'CREATE INDEX IF NOT EXISTS idx_records_session_user ON attendance_records(session_id, user_id)'
      );
      await this.rdbStore.executeSql(
        'CREATE INDEX IF NOT EXISTS idx_records_status_time ON attendance_records(status, check_in_time DESC)'
      );
      await this.rdbStore.executeSql(
        'CREATE INDEX IF NOT EXISTS idx_attempts_session_time ON check_in_attempts(session_id, attempt_time DESC)'
      );
      await this.rdbStore.executeSql(
        'CREATE INDEX IF NOT EXISTS idx_attempts_user_time ON check_in_attempts(user_id, attempt_time DESC)'
      );
      this.rdbStore.commit();
      Logger.info('数据库 v4 关系与位置模型迁移完成');
    } catch (error) {
      try {
        this.rdbStore.rollBack();
      } catch (rollbackError) {
        Logger.warn('数据库迁移回滚失败: %{public}s', JSON.stringify(rollbackError));
      }
      Logger.error('数据库关系模型迁移失败: %{public}s', JSON.stringify(error));
      const caughtError = error as Error;
      throw new Error(caughtError.message);
    }
  }

  /**
   * 关闭数据库
   */
  async close(): Promise<void> {
    if (this.rdbStore) {
      this.rdbStore = null;
      Logger.info('数据库已关闭');
    }
  }

  /**
   * 清除敏感的人脸与考勤数据，保留班级、课程和人员基础档案。
   */
  async clearSensitiveData(): Promise<void> {
    const store = this.getStore();
    try {
      store.beginTransaction();
      await store.executeSql('DELETE FROM check_in_attempts');
      await store.executeSql('DELETE FROM attendance_records');
      await store.executeSql('DELETE FROM session_members');
      await store.executeSql('DELETE FROM attendance_sessions');
      await store.executeSql(
        `UPDATE users
         SET face_image_path = '', face_enrolled = 0, updated_at = ?`,
        [Date.now()]
      );
      store.commit();
      Logger.info('敏感人脸与考勤数据已清除');
    } catch (error) {
      try {
        store.rollBack();
      } catch (rollbackError) {
        Logger.warn('敏感数据清理回滚失败: %{public}s', JSON.stringify(rollbackError));
      }
      const caughtError = error as Error;
      throw new Error(caughtError.message);
    }
  }
}
