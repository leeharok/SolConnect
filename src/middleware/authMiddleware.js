
require("dotenv/config");

const jwt = require("jsonwebtoken");

// 로그인 토큰 검증
function authenticateToken(req, res, next) {
  const authHeader = req.headers.authorization;

  // Authorization 헤더 확인
  if (!authHeader) {
    return res.status(401).json({
      success: false,
      message: "로그인이 필요한 서비스입니다."
    });
  }

  // Bearer 토큰 분리
  const [scheme, token] = authHeader.split(" ");

  if (scheme !== "Bearer" || !token) {
    return res.status(401).json({
      success: false,
      message: "인증 토큰 형식이 올바르지 않습니다."
    });
  }

  const secret = process.env.JWT_SECRET;

  if (!secret) {
    console.error("JWT_SECRET이 설정되지 않았습니다.");

    return res.status(500).json({
      success: false,
      message: "서버 인증 설정 오류입니다."
    });
  }

  try {
    // 토큰 검증
    const decoded = jwt.verify(token, secret);

    // 토큰 정보 확인
    if (
      typeof decoded === "string" ||
      typeof decoded.sub !== "string" ||
      !["MENTEE", "MENTOR", "ADMIN"].includes(decoded.role)
    ) {
      return res.status(401).json({
        success: false,
        message: "유효하지 않은 인증 토큰입니다."
      });
    }

    // 로그인한 사용자 정보 저장
    req.user = {
      id: decoded.sub,
      role: decoded.role
    };

    // 다음 단계로 이동
    next();

  } catch (error) {
    const message =
      error.name === "TokenExpiredError"
        ? "인증 토큰이 만료되었습니다."
        : "유효하지 않은 인증 토큰입니다.";

    return res.status(401).json({
      success: false,
      message
    });
  }
}

// 사용자 권한 확인
function authorizeRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: "로그인이 필요한 서비스입니다."
      });
    }

    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: "해당 기능에 접근할 권한이 없습니다."
      });
    }

    next();
  };
}

module.exports = {
  authenticateToken,
  authorizeRoles
};
