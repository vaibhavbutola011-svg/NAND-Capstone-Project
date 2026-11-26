DROP DATABASE IF EXISTS student_academic_db;
CREATE DATABASE student_academic_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE student_academic_db;

-- ---------------------------------------------------------------------
-- 1. DEPARTMENTS
-- ---------------------------------------------------------------------
CREATE TABLE departments (
    department_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    dept_code       VARCHAR(10)  NOT NULL,
    dept_name       VARCHAR(100) NOT NULL,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_dept_code UNIQUE (dept_code),
    CONSTRAINT uq_dept_name UNIQUE (dept_name)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. USERS  (authentication; 1:1 with students / faculty)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    email           VARCHAR(120) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    role            ENUM('admin','faculty','student') NOT NULL,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT chk_users_email CHECK (email LIKE '%_@_%._%')
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 3. SEMESTERS
-- ---------------------------------------------------------------------
CREATE TABLE semesters (
    semester_id     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    semester_number TINYINT UNSIGNED NOT NULL,
    academic_year   VARCHAR(9)   NOT NULL,           -- e.g. 2025-2026
    start_date      DATE         NOT NULL,
    end_date        DATE         NOT NULL,
    is_current      BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_semester UNIQUE (semester_number, academic_year),
    CONSTRAINT chk_sem_number CHECK (semester_number BETWEEN 1 AND 8),
    CONSTRAINT chk_sem_dates  CHECK (end_date > start_date)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 4. STUDENTS
-- ---------------------------------------------------------------------
CREATE TABLE students (
    student_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id          INT UNSIGNED NOT NULL,
    roll_number      VARCHAR(20)  NOT NULL,
    first_name       VARCHAR(50)  NOT NULL,
    last_name        VARCHAR(50)  NOT NULL,
    date_of_birth    DATE         NOT NULL,
    gender           ENUM('Male','Female','Other') NOT NULL,
    phone            VARCHAR(15)  NULL,
    address          VARCHAR(255) NULL,
    department_id    INT UNSIGNED NOT NULL,
    current_semester TINYINT UNSIGNED NOT NULL DEFAULT 1,
    admission_year   YEAR         NOT NULL,
    status           ENUM('active','graduated','suspended') NOT NULL DEFAULT 'active',
    CONSTRAINT uq_student_user  UNIQUE (user_id),
    CONSTRAINT uq_student_roll  UNIQUE (roll_number),
    CONSTRAINT chk_student_sem  CHECK (current_semester BETWEEN 1 AND 8),
    CONSTRAINT chk_student_phone CHECK (phone IS NULL OR phone REGEXP '^[0-9+ -]{7,15}$'),
    CONSTRAINT fk_student_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_student_dept FOREIGN KEY (department_id)
        REFERENCES departments(department_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_student_name (last_name, first_name),
    INDEX idx_student_dept (department_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 5. FACULTY
-- ---------------------------------------------------------------------
CREATE TABLE faculty (
    faculty_id      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id         INT UNSIGNED NOT NULL,
    employee_code   VARCHAR(20)  NOT NULL,
    first_name      VARCHAR(50)  NOT NULL,
    last_name       VARCHAR(50)  NOT NULL,
    phone           VARCHAR(15)  NULL,
    designation     VARCHAR(60)  NOT NULL DEFAULT 'Assistant Professor',
    department_id   INT UNSIGNED NOT NULL,
    joining_date    DATE         NOT NULL,
    CONSTRAINT uq_faculty_user UNIQUE (user_id),
    CONSTRAINT uq_faculty_code UNIQUE (employee_code),
    CONSTRAINT fk_faculty_user FOREIGN KEY (user_id)
        REFERENCES users(user_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_faculty_dept FOREIGN KEY (department_id)
        REFERENCES departments(department_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    INDEX idx_faculty_name (last_name, first_name),
    INDEX idx_faculty_dept (department_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 6. COURSES  (a course is offered in one semester, taught by one faculty)
-- ---------------------------------------------------------------------
CREATE TABLE courses (
    course_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    course_code     VARCHAR(15)  NOT NULL,
    course_name     VARCHAR(120) NOT NULL,
    credits         TINYINT UNSIGNED NOT NULL DEFAULT 3,
    department_id   INT UNSIGNED NOT NULL,
    semester_id     INT UNSIGNED NOT NULL,
    faculty_id      INT UNSIGNED NULL,                -- NULL = not yet assigned
    max_seats       SMALLINT UNSIGNED NOT NULL DEFAULT 60,
    CONSTRAINT uq_course_code_sem UNIQUE (course_code, semester_id),
    CONSTRAINT chk_course_credits CHECK (credits BETWEEN 1 AND 6),
    CONSTRAINT chk_course_seats   CHECK (max_seats > 0),
    CONSTRAINT fk_course_dept FOREIGN KEY (department_id)
        REFERENCES departments(department_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_course_sem FOREIGN KEY (semester_id)
        REFERENCES semesters(semester_id) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_course_faculty FOREIGN KEY (faculty_id)
        REFERENCES faculty(faculty_id) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_course_name (course_name),
    INDEX idx_course_faculty (faculty_id),
    INDEX idx_course_sem (semester_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 7. ENROLLMENTS  (resolves M:N between students and courses)
-- ---------------------------------------------------------------------
CREATE TABLE enrollments (
    enrollment_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    student_id      INT UNSIGNED NOT NULL,
    course_id       INT UNSIGNED NOT NULL,
    enrolled_on     DATE         NOT NULL DEFAULT (CURRENT_DATE),
    status          ENUM('enrolled','dropped','completed') NOT NULL DEFAULT 'enrolled',
    CONSTRAINT uq_enrollment UNIQUE (student_id, course_id),
    CONSTRAINT fk_enr_student FOREIGN KEY (student_id)
        REFERENCES students(student_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_enr_course FOREIGN KEY (course_id)
        REFERENCES courses(course_id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_enr_course (course_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 8. ATTENDANCE  (one row per enrollment per class date)
-- ---------------------------------------------------------------------
CREATE TABLE attendance (
    attendance_id   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    enrollment_id   INT UNSIGNED NOT NULL,
    attendance_date DATE         NOT NULL,
    status          ENUM('present','absent','late') NOT NULL DEFAULT 'present',
    marked_by       INT UNSIGNED NULL,                -- faculty who marked it
    CONSTRAINT uq_attendance UNIQUE (enrollment_id, attendance_date),
    CONSTRAINT fk_att_enr FOREIGN KEY (enrollment_id)
        REFERENCES enrollments(enrollment_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_att_faculty FOREIGN KEY (marked_by)
        REFERENCES faculty(faculty_id) ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_att_date (attendance_date)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 9. EXAMINATIONS
-- ---------------------------------------------------------------------
CREATE TABLE examinations (
    exam_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    course_id       INT UNSIGNED NOT NULL,
    exam_name       VARCHAR(80)  NOT NULL,
    exam_type       ENUM('internal','midterm','final','assignment') NOT NULL,
    exam_date       DATE         NOT NULL,
    max_marks       DECIMAL(5,2) NOT NULL,
    CONSTRAINT uq_exam UNIQUE (course_id, exam_name),
    CONSTRAINT chk_exam_max CHECK (max_marks > 0),
    CONSTRAINT fk_exam_course FOREIGN KEY (course_id)
        REFERENCES courses(course_id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_exam_date (exam_date)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 10. MARKS
-- ---------------------------------------------------------------------
CREATE TABLE marks (
    mark_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    exam_id         INT UNSIGNED NOT NULL,
    enrollment_id   INT UNSIGNED NOT NULL,
    marks_obtained  DECIMAL(5,2) NOT NULL,
    CONSTRAINT uq_marks UNIQUE (exam_id, enrollment_id),
    CONSTRAINT chk_marks_nonneg CHECK (marks_obtained >= 0),
    CONSTRAINT fk_marks_exam FOREIGN KEY (exam_id)
        REFERENCES examinations(exam_id) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_marks_enr FOREIGN KEY (enrollment_id)
        REFERENCES enrollments(enrollment_id) ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_marks_enr (enrollment_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 11. GRADES  (1:1 with enrollment; computed by sp_compute_grades)
-- ---------------------------------------------------------------------
CREATE TABLE grades (
    grade_id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    enrollment_id    INT UNSIGNED NOT NULL,
    total_percentage DECIMAL(5,2) NOT NULL DEFAULT 0,
    letter_grade     VARCHAR(2)   NOT NULL,
    grade_points     DECIMAL(3,1) NOT NULL,
    computed_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
                                  ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uq_grade_enr UNIQUE (enrollment_id),
    CONSTRAINT chk_grade_pct CHECK (total_percentage BETWEEN 0 AND 100),
    CONSTRAINT chk_grade_pts CHECK (grade_points BETWEEN 0 AND 10),
    CONSTRAINT fk_grade_enr FOREIGN KEY (enrollment_id)
        REFERENCES enrollments(enrollment_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- TRIGGERS: marks_obtained must not exceed the exam's max_marks
-- (a CHECK cannot reference another table, so a trigger enforces it)
-- =====================================================================
DELIMITER $$

CREATE TRIGGER trg_marks_before_insert
BEFORE INSERT ON marks
FOR EACH ROW
BEGIN
    DECLARE v_max DECIMAL(5,2);
    SELECT max_marks INTO v_max FROM examinations WHERE exam_id = NEW.exam_id;
    IF NEW.marks_obtained > v_max THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'marks_obtained cannot exceed the exam max_marks';
    END IF;
END$$

CREATE TRIGGER trg_marks_before_update
BEFORE UPDATE ON marks
FOR EACH ROW
BEGIN
    DECLARE v_max DECIMAL(5,2);
    SELECT max_marks INTO v_max FROM examinations WHERE exam_id = NEW.exam_id;
    IF NEW.marks_obtained > v_max THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'marks_obtained cannot exceed the exam max_marks';
    END IF;
END$$

-- Prevent enrolling beyond a course's seat limit
CREATE TRIGGER trg_enrollment_seat_check
BEFORE INSERT ON enrollments
FOR EACH ROW
BEGIN
    DECLARE v_taken INT;
    DECLARE v_max   INT;
    SELECT COUNT(*) INTO v_taken FROM enrollments
        WHERE course_id = NEW.course_id AND status = 'enrolled';
    SELECT max_seats INTO v_max FROM courses WHERE course_id = NEW.course_id;
    IF v_taken >= v_max THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Course is full';
    END IF;
END$$

-- =====================================================================
-- STORED PROCEDURE: compute grades for every enrollment in a course
-- Grade scale (10-point): >=90 O/10, >=80 A+/9, >=70 A/8, >=60 B+/7,
--                         >=50 B/6, >=40 C/5, else F/0
-- =====================================================================
CREATE PROCEDURE sp_compute_grades(IN p_course_id INT UNSIGNED)
BEGIN
    INSERT INTO grades (enrollment_id, total_percentage, letter_grade, grade_points)
    SELECT t.enrollment_id,
           t.pct,
           CASE WHEN t.pct >= 90 THEN 'O'
                WHEN t.pct >= 80 THEN 'A+'
                WHEN t.pct >= 70 THEN 'A'
                WHEN t.pct >= 60 THEN 'B+'
                WHEN t.pct >= 50 THEN 'B'
                WHEN t.pct >= 40 THEN 'C'
                ELSE 'F' END,
           CASE WHEN t.pct >= 90 THEN 10
                WHEN t.pct >= 80 THEN 9
                WHEN t.pct >= 70 THEN 8
                WHEN t.pct >= 60 THEN 7
                WHEN t.pct >= 50 THEN 6
                WHEN t.pct >= 40 THEN 5
                ELSE 0 END
    FROM (
        SELECT en.enrollment_id,
               ROUND(SUM(m.marks_obtained) / SUM(ex.max_marks) * 100, 2) AS pct
        FROM enrollments en
        JOIN marks m         ON m.enrollment_id = en.enrollment_id
        JOIN examinations ex ON ex.exam_id = m.exam_id
        WHERE en.course_id = p_course_id AND en.status <> 'dropped'
        GROUP BY en.enrollment_id
    ) AS t
    ON DUPLICATE KEY UPDATE
        total_percentage = VALUES(total_percentage),
        letter_grade     = VALUES(letter_grade),
        grade_points     = VALUES(grade_points);
END$$

DELIMITER ;

-- =====================================================================
-- VIEWS
-- =====================================================================

-- Attendance percentage per student per course
CREATE OR REPLACE VIEW vw_attendance_report AS
SELECT  s.student_id,
        s.roll_number,
        CONCAT(s.first_name, ' ', s.last_name) AS student_name,
        c.course_id,
        c.course_code,
        c.course_name,
        COUNT(a.attendance_id)                                   AS total_classes,
        SUM(a.status IN ('present','late'))                      AS classes_attended,
        ROUND(100 * SUM(a.status IN ('present','late'))
              / NULLIF(COUNT(a.attendance_id), 0), 2)            AS attendance_percentage
FROM enrollments en
JOIN students s ON s.student_id = en.student_id
JOIN courses  c ON c.course_id  = en.course_id
LEFT JOIN attendance a ON a.enrollment_id = en.enrollment_id
WHERE en.status <> 'dropped'
GROUP BY s.student_id, s.roll_number, s.first_name, s.last_name,
         c.course_id, c.course_code, c.course_name;

-- Academic performance: one row per enrollment with grade
CREATE OR REPLACE VIEW vw_academic_performance AS
SELECT  s.student_id,
        s.roll_number,
        CONCAT(s.first_name, ' ', s.last_name) AS student_name,
        d.dept_name,
        sem.semester_id,
        sem.semester_number,
        sem.academic_year,
        c.course_id,
        c.course_code,
        c.course_name,
        c.credits,
        g.total_percentage,
        g.letter_grade,
        g.grade_points
FROM enrollments en
JOIN students    s   ON s.student_id    = en.student_id
JOIN departments d   ON d.department_id = s.department_id
JOIN courses     c   ON c.course_id     = en.course_id
JOIN semesters   sem ON sem.semester_id = c.semester_id
LEFT JOIN grades g   ON g.enrollment_id = en.enrollment_id
WHERE en.status <> 'dropped';

-- CGPA = credit-weighted average of grade points over graded courses
CREATE OR REPLACE VIEW vw_student_cgpa AS
SELECT  student_id,
        roll_number,
        student_name,
        SUM(credits)                                        AS credits_graded,
        ROUND(SUM(grade_points * credits) / SUM(credits), 2) AS cgpa
FROM vw_academic_performance
WHERE grade_points IS NOT NULL
GROUP BY student_id, roll_number, student_name;
