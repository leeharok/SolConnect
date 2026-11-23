require("dotenv/config");

const express = require("express");
const cors = require("cors");
const http = require("http");
const path = require("path");

const { Server } = require("socket.io");

const apiRoutes = require("./src/routes");
const initializeChatSocket = require("./src/sockets/chatSocket");

const app = express();

const corsOptions = {
  origin: (origin, callback) => {
    // 브라우저가 아닌 요청(curl 등)은 허용
    if (!origin) {
      return callback(null, true);
    }

    // 로컬 Flutter 개발 서버 허용
    const allowedOrigin =
      /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

    if (allowedOrigin.test(origin)) {
      return callback(null, true);
    }

    return callback(new Error("허용되지 않은 접속 주소입니다."));
  },
  methods: ["GET", "POST", "PUT", "PATCH", "DELETE"],
  allowedHeaders: ["Content-Type", "Authorization"],
};

// CORS 설정
app.use(cors(corsOptions));

// JSON 요청 처리
app.use(express.json());

// 업로드된 이미지 파일 접근 경로
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// API 라우터 연결
app.use("/api", apiRoutes);

// HTTP 서버 생성
const httpServer = http.createServer(app);

// Socket.IO 서버 생성
const io = new Server(httpServer, {
  cors: corsOptions,
});

// Express에서 Socket.IO 객체 사용
app.set("io", io);

// 실시간 채팅 서버 연결
initializeChatSocket(io);

// 서버 실행
const PORT = 3000;

httpServer.listen(PORT, () => {
  console.log(`서버 실행 중: http://localhost:${PORT}`);
  console.log("Socket.IO 채팅 서버 연결 완료!");
});