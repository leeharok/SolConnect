
const express = require("express");
const router = express.Router();

const { getHealth } = require("../controllers/healthController");

const authRoutes = require("./authRoutes");
const questionRoutes = require("./questionRoutes");
const chatRoutes = require("./chatRoutes");
const pointsRoutes = require("./pointsRoutes");
const notificationRoutes = require("./notificationRoutes");
const reviewRoutes = require("./reviewRoutes");

// 서버 상태 확인
router.get("/health", getHealth);

// 회원 관련 API
router.use("/auth", authRoutes);

// 질문 관련 API
router.use("/questions", questionRoutes);

// 채팅 관련 API
router.use("/chats", chatRoutes);

// 포인트 관련 API
router.use("/points", pointsRoutes);

// 알림 관련 API
router.use("/notifications", notificationRoutes);

// 후기 관련 API
router.use("/reviews", reviewRoutes);

module.exports = router;
