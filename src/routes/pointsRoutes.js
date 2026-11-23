const express = require("express");
const router = express.Router();

const {
  authenticateToken,
  authorizeRoles
} = require("../middleware/authMiddleware");

const {
  getMyPointTransactions
} = require("../controllers/pointsController");

// 멘토 본인의 포인트 잔액 및 내역 조회
router.get(
  "/",
  authenticateToken,
  authorizeRoles("MENTOR"),
  getMyPointTransactions
);

module.exports = router;
