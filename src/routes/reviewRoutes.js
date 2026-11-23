const express = require("express");
const router = express.Router();

const {
  authenticateToken,
  authorizeRoles
} = require("../middleware/authMiddleware");

const {
  getReceivedReviews
} = require("../controllers/reviewController");

// 멘토 전용 받은 후기 목록
router.get(
  "/received",
  authenticateToken,
  authorizeRoles("MENTOR"),
  getReceivedReviews
);

module.exports = router;
