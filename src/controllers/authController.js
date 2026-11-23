
require("dotenv/config");

const prisma = require("../config/prisma");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

// 공통 사용자 응답 데이터
function formatUser(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    schoolLevel: user.schoolLevel,
    schoolName: user.schoolName,
    grade: user.grade,
    schoolVerified: user.schoolVerified,
    department: user.department,
    studentId: user.studentId,
    subjects: user.subjects,
    bio: user.bio,
    mentorApproved: user.mentorApproved,
    points: user.points,
    createdAt: user.createdAt
  };
}

// JWT 발급
function createAccessToken(user) {
  const secret = process.env.JWT_SECRET;

  if (!secret) {
    throw new Error("JWT_SECRET이 설정되지 않았습니다.");
  }

  const expiresIn = process.env.JWT_EXPIRES_IN || "1h";

  const accessToken = jwt.sign(
    { role: user.role },
    secret,
    {
      subject: user.id,
      expiresIn
    }
  );

  return { accessToken, expiresIn };
}

// 초대코드 검증
function isValidInviteCode(code) {
  const codes = (process.env.MENTEE_INVITE_CODES || "")
    .split(",")
    .map(value => value.trim().toUpperCase())
    .filter(Boolean);

  return codes.includes(
    typeof code === "string" ? code.trim().toUpperCase() : ""
  );
}

// 초대코드 확인 API
async function verifyInviteCode(req, res) {
  try {
    const { inviteCode } = req.body || {};

    if (!process.env.MENTEE_INVITE_CODES) {
      return res.status(503).json({
        success: false,
        message: "초대코드 설정을 확인할 수 없습니다."
      });
    }

    if (
      typeof inviteCode !== "string" ||
      !isValidInviteCode(inviteCode)
    ) {
      return res.status(400).json({
        success: false,
        message: "유효하지 않은 초대코드입니다."
      });
    }

    return res.status(200).json({
      success: true,
      message: "초대코드 인증에 성공했습니다."
    });

  } catch (error) {
    console.error("초대코드 검증 오류:", error);

    return res.status(500).json({
      success: false,
      message: "초대코드 검증 중 오류가 발생했습니다."
    });
  }
}

// 회원가입
async function register(req, res) {
  try {
    const {
      name,
      email,
      password,
      role,
      schoolLevel,
      schoolName,
      grade,
      department,
      studentId,
      subjects,
      bio,
      inviteCode
    } = req.body || {};

    // 필수 입력값 검사
    if (
      typeof name !== "string" ||
      typeof email !== "string" ||
      typeof password !== "string" ||
      typeof role !== "string"
    ) {
      return res.status(400).json({
        success: false,
        message: "필수 입력값을 확인해 주세요."
      });
    }

    const cleanName = name.trim();
    const cleanEmail = email.trim().toLowerCase();

    if (!cleanName || cleanName.length > 12) {
      return res.status(400).json({
        success: false,
        message: "닉네임은 1~12자로 입력해 주세요."
      });
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanEmail)) {
      return res.status(400).json({
        success: false,
        message: "올바른 이메일을 입력해 주세요."
      });
    }

    if (password.length < 8 || Buffer.byteLength(password, "utf8") > 72) {
      return res.status(400).json({
        success: false,
        message: "비밀번호는 8자 이상 72바이트 이하로 입력해 주세요."
      });
    }

    if (!["MENTEE", "MENTOR"].includes(role)) {
      return res.status(400).json({
        success: false,
        message: "올바른 회원 유형이 아닙니다."
      });
    }

    // 멘티 프로필 검증
    if (role === "MENTEE") {
      const levels = ["ELEMENTARY", "MIDDLE", "HIGH"];

      const maxGrade = schoolLevel === "ELEMENTARY" ? 6 : 3;

      if (
        !levels.includes(schoolLevel) ||
        typeof schoolName !== "string" ||
        !schoolName.trim() ||
        !Number.isInteger(grade) ||
        grade < 1 ||
        grade > maxGrade
      ) {
        return res.status(400).json({
          success: false,
          message: "학교급, 학교 이름, 학년을 확인해 주세요."
        });
      }

      if (!isValidInviteCode(inviteCode)) {
        return res.status(400).json({
          success: false,
          message: "유효한 학교 초대코드가 필요합니다."
        });
      }
    }

    // 멘토 프로필 검증
    let cleanSubjects = [];

    if (role === "MENTOR") {
      if (
        typeof department !== "string" ||
        !department.trim() ||
        typeof studentId !== "string" ||
        !studentId.trim() ||
        !Array.isArray(subjects) ||
        subjects.length === 0 ||
        subjects.length > 7 ||
        !subjects.every(
          item => typeof item === "string" && item.trim().length > 0 && item.length <= 50
        )
      ) {
        return res.status(400).json({
          success: false,
          message: "학과, 학번, 담당 과목을 확인해 주세요."
        });
      }

      cleanSubjects = [...new Set(subjects.map(item => item.trim()))];
    }

    if (
      bio !== undefined &&
      bio !== null &&
      (typeof bio !== "string" || bio.length > 500)
    ) {
      return res.status(400).json({
        success: false,
        message: "소개는 500자 이하로 작성해 주세요."
      });
    }

    // 비밀번호 해시
    const passwordHash = await bcrypt.hash(password, 12);

    // 사용자 생성
    const user = await prisma.user.create({
      data: {
        name: cleanName,
        email: cleanEmail,
        passwordHash,
        role,

        schoolLevel: role === "MENTEE" ? schoolLevel : null,
        schoolName: role === "MENTEE" ? schoolName.trim() : null,
        grade: role === "MENTEE" ? grade : null,
        schoolVerified: role === "MENTEE",

        department: role === "MENTOR" ? department.trim() : null,
        studentId: role === "MENTOR" ? studentId.trim() : null,
        subjects: cleanSubjects,
        bio: bio?.trim() || null,

        mentorApproved: false
      }
    });

    // 회원가입 완료 후 자동 로그인 토큰 발급
    const token = createAccessToken(user);

    return res.status(201).json({
      success: true,
      message: "회원가입이 완료되었습니다.",
      tokenType: "Bearer",
      ...token,
      user: formatUser(user)
    });

  } catch (error) {
    if (error.code === "P2002") {
      return res.status(409).json({
        success: false,
        message: "이미 가입된 이메일입니다."
      });
    }

    console.error("회원가입 오류:", error);

    return res.status(500).json({
      success: false,
      message: "회원가입 중 서버 오류가 발생했습니다."
    });
  }
}

// 로그인
async function login(req, res) {
  try {
    const { email, password } = req.body || {};

    if (
      typeof email !== "string" ||
      typeof password !== "string" ||
      !email.trim() ||
      !password
    ) {
      return res.status(400).json({
        success: false,
        message: "이메일과 비밀번호를 입력해 주세요."
      });
    }

    const user = await prisma.user.findUnique({
      where: {
        email: email.trim().toLowerCase()
      }
    });

    if (
      !user ||
      !(await bcrypt.compare(password, user.passwordHash))
    ) {
      return res.status(401).json({
        success: false,
        message: "이메일 또는 비밀번호가 올바르지 않습니다."
      });
    }

    const token = createAccessToken(user);

    return res.status(200).json({
      success: true,
      message: "로그인에 성공했습니다.",
      tokenType: "Bearer",
      ...token,
      user: formatUser(user)
    });

  } catch (error) {
    console.error("로그인 오류:", error);

    return res.status(500).json({
      success: false,
      message: "로그인 중 서버 오류가 발생했습니다."
    });
  }
}

// 내 회원 정보 조회
async function getMe(req, res) {
  try {
    const user = await prisma.user.findUnique({
      where: {
        id: req.user.id
      }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "회원 정보를 찾을 수 없습니다."
      });
    }

    return res.status(200).json({
      success: true,
      message: "회원 정보 조회 성공",
      user: formatUser(user)
    });

  } catch (error) {
    console.error("회원 정보 조회 오류:", error);

    return res.status(500).json({
      success: false,
      message: "회원 정보 조회 중 서버 오류가 발생했습니다."
    });
  }
}

module.exports = {
  register,
  login,
  getMe,
  verifyInviteCode
};
