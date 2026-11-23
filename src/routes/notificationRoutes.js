const express = require("express");
const router = express.Router();

const {
  authenticateToken
} = require("../middleware/authMiddleware");

const {
  getMyNotifications,
  getUnreadNotificationCount,
  markNotificationAsRead,
  markAllNotificationsAsRead
} = require("../controllers/notificationController");

// 내 알림 목록
router.get(
  "/",
  authenticateToken,
  getMyNotifications
);

// 안 읽은 알림 개수
router.get(
  "/unread-count",
  authenticateToken,
  getUnreadNotificationCount
);

// 알림 전체 읽음
router.patch(
  "/read-all",
  authenticateToken,
  markAllNotificationsAsRead
);

// 알림 하나 읽음
router.patch(
  "/:id/read",
  authenticateToken,
  markNotificationAsRead
);

module.exports = router;
