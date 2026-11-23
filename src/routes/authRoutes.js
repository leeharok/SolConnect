
const express = require("express");
const router = express.Router();

const {
  register,
  login,
  getMe,
  verifyInviteCode
} = require("../controllers/authController");

const {
  authenticateToken
} = require("../middleware/authMiddleware");

// 회원가입
router.post("/register", register);

// 로그인
router.post("/login", login);

// 내 정보
router.get("/me", authenticateToken, getMe);

// 학교 초대코드 검증
router.post("/verify-invite", verifyInviteCode);

module.exports = router;
