const express = require("express");
const router = express.Router();

const {
  authenticateToken,
  authorizeRoles
} = require("../middleware/authMiddleware");

const {
  uploadQuestionImages
} = require("../middleware/upload");

const {
  createQuestion
} = require("../controllers/createQuestionController");

const {
  getAvailableQuestions,
  getMyQuestions,
  acceptQuestion
} = require("../controllers/questionController");

// 멘티 전용 질문 등록
router.post(
  "/",
  authenticateToken,
  authorizeRoles("MENTEE"),
  uploadQuestionImages,
  createQuestion
);

// 멘티 본인이 등록한 질문 목록
router.get(
  "/mine",
  authenticateToken,
  authorizeRoles("MENTEE"),
  getMyQuestions
);

// 멘토 전용 질문 목록 조회
router.get(
  "/available",
  authenticateToken,
  authorizeRoles("MENTOR"),
  getAvailableQuestions
);

// 멘토 전용 질문 수락 및 매칭
router.post(
  "/:id/accept",
  authenticateToken,
  authorizeRoles("MENTOR"),
  acceptQuestion
);

module.exports = router;
