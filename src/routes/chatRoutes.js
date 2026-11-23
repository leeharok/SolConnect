const express = require("express");
const router = express.Router();

const {
  authenticateToken,
  authorizeRoles
} = require("../middleware/authMiddleware");

const {
  getMyChatRooms,
  getChatMessages,
  getUnreadChatCount,
  requestChatCompletion,
  confirmChatCompletion
} = require("../controllers/chatController");

const { submitReview } = require("../controllers/reviewController");

router.get(
  "/",
  authenticateToken,
  getMyChatRooms
);

// 안 읽은 채팅 메시지 수 조회
router.get(
  "/unread-count",
  authenticateToken,
  getUnreadChatCount
);

router.get(
  "/:chatRoomId/messages",
  authenticateToken,
  getChatMessages
);

router.post(
  "/:chatRoomId/request-completion",
  authenticateToken,
  authorizeRoles("MENTOR"),
  requestChatCompletion
);

router.post(
  "/:chatRoomId/confirm-completion",
  authenticateToken,
  authorizeRoles("MENTEE"),
  confirmChatCompletion
);

router.post(
  "/:chatRoomId/review",
  authenticateToken,
  authorizeRoles("MENTEE"),
  submitReview
);

module.exports = router;
