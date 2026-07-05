import { OrganizationDao } from '../database/OrganizationDao';
import { UserDao } from '../database/UserDao';
import { Course, DataStatus } from '../models/OrganizationModel';
import { UserFormData, UserModel } from '../models/UserModel';

interface DemoClassSpec {
  name: string;
  grade: string;
  major: string;
}

interface DemoCourseSpec {
  code: string;
  name: string;
}

interface DemoStudentSpec {
  studentNo: string;
  name: string;
  classIndex: number;
  courseIndexes: number[];
}

export interface DemoDataResult {
  classCount: number;
  courseCount: number;
  userCount: number;
}

export class DemoDataService {
  private organizationDao: OrganizationDao = new OrganizationDao();
  private userDao: UserDao = new UserDao();

  private demoClassSpecs: DemoClassSpec[] = [
    { name: '演示一班', grade: '2026', major: '鸿蒙应用开发' },
    { name: '演示二班', grade: '2026', major: '智能终端技术' }
  ];

  private demoCourseSpecs: DemoCourseSpec[] = [
    { code: 'DEMO-OS', name: '鸿蒙应用开发演示课' },
    { code: 'DEMO-AI', name: 'AI Core Vision 实训课' }
  ];

  private demoStudentSpecs: DemoStudentSpec[] = [
    { studentNo: 'D2026001', name: '演示学生01', classIndex: 0, courseIndexes: [0, 1] },
    { studentNo: 'D2026002', name: '演示学生02', classIndex: 0, courseIndexes: [0] },
    { studentNo: 'D2026003', name: '演示学生03', classIndex: 0, courseIndexes: [0, 1] },
    { studentNo: 'D2026004', name: '演示学生04', classIndex: 1, courseIndexes: [1] },
    { studentNo: 'D2026005', name: '演示学生05', classIndex: 1, courseIndexes: [0, 1] },
    { studentNo: 'D2026006', name: '演示学生06', classIndex: 1, courseIndexes: [1] }
  ];

  async generateDemoData(): Promise<DemoDataResult> {
    const classIds: number[] = [];
    const courseIds: number[] = [];

    for (const classSpec of this.demoClassSpecs) {
      const classId = await this.ensureDemoClass(classSpec);
      classIds.push(classId);
    }

    for (const courseSpec of this.demoCourseSpecs) {
      const courseId = await this.ensureDemoCourse(courseSpec);
      courseIds.push(courseId);
    }

    for (const studentSpec of this.demoStudentSpecs) {
      const classId = classIds[studentSpec.classIndex] ?? 0;
      const className = this.demoClassSpecs[studentSpec.classIndex]?.name ?? '演示班级';
      const enrolledCourseIds = this.resolveCourseIds(studentSpec.courseIndexes, courseIds);
      await this.upsertDemoStudent(studentSpec, classId, className, enrolledCourseIds);
    }

    return {
      classCount: this.demoClassSpecs.length,
      courseCount: this.demoCourseSpecs.length,
      userCount: this.demoStudentSpecs.length
    };
  }

  async clearDemoData(): Promise<DemoDataResult> {
    let archivedUsers = 0;
    let archivedCourses = 0;
    let archivedClasses = 0;

    const users = await this.userDao.getAll(true);
    for (const user of users) {
      if (this.isDemoStudent(user)) {
        await this.userDao.archive(user.id);
        await this.organizationDao.archiveUserEnrollments(user.id);
        archivedUsers += 1;
      }
    }

    const courses = await this.organizationDao.getCourses(true);
    for (const course of courses) {
      if (course.code.startsWith('DEMO-')) {
        await this.organizationDao.updateCourseStatus(course.id, DataStatus.ARCHIVED);
        archivedCourses += 1;
      }
    }

    const classes = await this.organizationDao.getClasses(true);
    for (const classInfo of classes) {
      if (this.isDemoClassName(classInfo.name)) {
        await this.organizationDao.updateClassStatus(classInfo.id, DataStatus.ARCHIVED);
        archivedClasses += 1;
      }
    }

    return {
      classCount: archivedClasses,
      courseCount: archivedCourses,
      userCount: archivedUsers
    };
  }

  private async ensureDemoClass(classSpec: DemoClassSpec): Promise<number> {
    const existing = await this.organizationDao.getClassByName(classSpec.name);
    if (existing) {
      if (existing.status === DataStatus.ARCHIVED) {
        await this.organizationDao.updateClassStatus(existing.id, DataStatus.ACTIVE);
      }
      return existing.id;
    }
    return await this.organizationDao.insertClass(classSpec.name, classSpec.grade, classSpec.major);
  }

  private async ensureDemoCourse(courseSpec: DemoCourseSpec): Promise<number> {
    const courses = await this.organizationDao.getCourses(true);
    const existing = courses.find((course: Course) => course.code === courseSpec.code);
    if (existing) {
      if (existing.status === DataStatus.ARCHIVED) {
        await this.organizationDao.updateCourseStatus(existing.id, DataStatus.ACTIVE);
      }
      return existing.id;
    }
    return await this.organizationDao.insertCourse(courseSpec.code, courseSpec.name);
  }

  private async upsertDemoStudent(
    studentSpec: DemoStudentSpec,
    classId: number,
    className: string,
    courseIds: number[]
  ): Promise<void> {
    const formData: UserFormData = {
      studentNo: studentSpec.studentNo,
      name: studentSpec.name,
      classId: classId,
      className: className,
      courseIds: courseIds
    };
    const existing = await this.userDao.getByStudentNo(studentSpec.studentNo);
    if (existing) {
      await this.userDao.restore(existing.id);
      await this.userDao.update(existing.id, formData);
      await this.organizationDao.setUserEnrollments(existing.id, courseIds);
      return;
    }
    const userId = await this.userDao.insert(formData);
    await this.organizationDao.setUserEnrollments(userId, courseIds);
  }

  private resolveCourseIds(indexes: number[], courseIds: number[]): number[] {
    const resolved: number[] = [];
    for (const courseIndex of indexes) {
      const courseId = courseIds[courseIndex] ?? 0;
      if (courseId > 0) {
        resolved.push(courseId);
      }
    }
    return resolved;
  }

  private isDemoStudent(user: UserModel): boolean {
    return user.studentNo.startsWith('D2026') && user.name.startsWith('演示学生');
  }

  private isDemoClassName(className: string): boolean {
    return className === '演示一班' || className === '演示二班';
  }
}
