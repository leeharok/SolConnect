
require("dotenv/config");

const jwt = require("jsonwebtoken");
const prisma = require("../config/prisma");
const { createNotification } = require("../utils/notificationHelper");

// Socket.IO 채팅 서버 설정
function initializeChatSocket(io) {

  // 1. JWT 인증 미들웨어
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth?.token;
      const secret = process.env.JWT_SECRET;

      if (!secret) {
        return next(new Error("서버 인증 설정 오류입니다."));
      }

      if (typeof token !== "string" || !token) {
        return next(new Error("인증 토큰이 필요합니다."));
      }

      const decoded = jwt.verify(token, secret);

      if (
        typeof decoded === "string" ||
        typeof decoded.sub !== "string"
      ) {
        return next(new Error("유효하지 않은 토큰입니다."));
      }

      // 실제 회원 정보 확인
      const user = await prisma.user.findUnique({
        where: {
          id: decoded.sub
        },
        select: {
          id: true,
          role: true
        }
      });

      if (!user || user.role !== decoded.role) {
        return next(new Error("인증할 수 없는 사용자입니다."));
      }

      // 소켓에 사용자 정보 저장
      socket.data.user = {
        id: user.id,
        role: user.role
      };

      next();

    } catch (error) {
      const message =
        error.name === "TokenExpiredError"
          ? "인증 토큰이 만료되었습니다."
          : "유효하지 않은 인증 토큰입니다.";

      next(new Error(message));
    }
  });


  // 2. 사용자 연결
  io.on("connection", (socket) => {

    console.log(
      `채팅 서버 연결: ${socket.data.user.id}`
    );


    // 3. 채팅방 입장
    socket.on("chat:join", async (data, callback) => {
      const reply =
        typeof callback === "function" ? callback : () => {};

      try {
        const chatRoomId =
          typeof data?.chatRoomId === "string"
            ? data.chatRoomId.trim()
            : "";

        if (!chatRoomId) {
          return reply({
            success: false,
            message: "채팅방 ID가 필요합니다."
          });
        }

        // 채팅방 조회
        const chatRoom = await prisma.chatRoom.findUnique({
          where: {
            id: chatRoomId
          },
          select: {
            id: true,
            menteeId: true,
            mentorId: true,
            status: true
          }
        });

        if (!chatRoom) {
          return reply({
            success: false,
            message: "채팅방을 찾을 수 없습니다."
          });
        }

        // 채팅방 참여자 확인
        const userId = socket.data.user.id;

        if (
          chatRoom.menteeId !== userId &&
          chatRoom.mentorId !== userId
        ) {
          return reply({
            success: false,
            message: "채팅방에 접근할 권한이 없습니다."
          });
        }

        // 진행 중이거나 멘티의 완료 확인을 기다리는 채팅방 입장 허용
        if (
          !["ACTIVE", "COMPLETION_REQUESTED"].includes(chatRoom.status)
        ) {
          return reply({
            success: false,
            message: "종료된 채팅방입니다."
          });
        }

        const roomName = `chat:${chatRoomId}`;

        await socket.join(roomName);

        reply({
          success: true,
          message: "채팅방에 입장했습니다.",
          chatRoomId
        });

      } catch (error) {
        console.error("채팅방 입장 오류:", error);

        reply({
          success: false,
          message: "채팅방 입장 중 오류가 발생했습니다."
        });
      }
    });


    // 4. 메시지 전송
    socket.on("chat:send", async (data, callback) => {
      const reply =
        typeof callback === "function" ? callback : () => {};

      try {
        const { chatRoomId, content } = data || {};

        if (
          typeof chatRoomId !== "string" ||
          !chatRoomId.trim() ||
          typeof content !== "string" ||
          !content.trim() ||
          content.trim().length > 5000
        ) {
          return reply({
            success: false,
            message: "메시지 내용을 확인해 주세요."
          });
        }

        const roomId = chatRoomId.trim();
        const roomName = `chat:${roomId}`;

        // 먼저 채팅방에 입장했는지 확인
        if (!socket.rooms.has(roomName)) {
          return reply({
            success: false,
            message: "먼저 채팅방에 입장해 주세요."
          });
        }

        // 채팅방 참여 권한 재확인
        const chatRoom = await prisma.chatRoom.findUnique({
          where: {
            id: roomId
          },
          select: {
            menteeId: true,
            mentorId: true,
            status: true
          }
        });

        if (!chatRoom) {
          return reply({
            success: false,
            message: "채팅방을 찾을 수 없습니다."
          });
        }

        const userId = socket.data.user.id;

        if (
          chatRoom.menteeId !== userId &&
          chatRoom.mentorId !== userId
        ) {
          return reply({
            success: false,
            message: "메시지를 전송할 권한이 없습니다."
          });
        }

        if (chatRoom.status !== "ACTIVE") {
          return reply({
            success: false,
            message: "종료된 채팅방에는 메시지를 보낼 수 없습니다."
          });
        }

        // DB에 메시지 저장
        const message = await prisma.chatMessage.create({
          data: {
            chatRoomId: roomId,
            senderId: userId,
            content: content.trim()
          },
          include: {
            sender: {
              select: {
                id: true,
                name: true
              }
            }
          }
        });

        const messageData = {
          id: message.id,
          chatRoomId: message.chatRoomId,
          senderId: message.senderId,
          senderName: message.sender.name,
          content: message.content,
          createdAt: message.createdAt
        };

        // 메시지를 받는 상대방에게 알림 저장
        const recipientId =
          chatRoom.menteeId === userId
            ? chatRoom.mentorId
            : chatRoom.menteeId;

        await createNotification({
          userId: recipientId,
          type: "CHAT_MESSAGE",
          title: `${message.sender.name}님의 새 메시지`,
          body: message.content.length > 120
            ? `${message.content.slice(0, 120)}...`
            : message.content,
          chatRoomId: roomId
        });

        // 같은 채팅방 참여자에게 실시간 전달
        io.to(roomName).emit(
          "chat:message",
          messageData
        );

        reply({
          success: true,
          message: "메시지가 전송되었습니다.",
          data: messageData
        });

      } catch (error) {
        console.error("메시지 전송 오류:", error);

        reply({
          success: false,
          message: "메시지 전송 중 오류가 발생했습니다."
        });
      }
    });


    // 6. 채팅 메시지 읽음 처리
    socket.on("chat:read", async (data, callback) => {
      const reply =
        typeof callback === "function" ? callback : () => {};

      try {
        const chatRoomId =
          typeof data?.chatRoomId === "string"
            ? data.chatRoomId.trim()
            : "";

        if (!chatRoomId) {
          return reply({
            success: false,
            message: "채팅방 ID가 필요합니다."
          });
        }

        const roomName = `chat:${chatRoomId}`;

        // 채팅방 입장 여부 확인
        if (!socket.rooms.has(roomName)) {
          return reply({
            success: false,
            message: "먼저 채팅방에 입장해 주세요."
          });
        }

        // 채팅방 참여자 확인
        const chatRoom = await prisma.chatRoom.findUnique({
          where: { id: chatRoomId },
          select: {
            menteeId: true,
            mentorId: true,
            status: true
          }
        });

        if (!chatRoom) {
          return reply({
            success: false,
            message: "채팅방을 찾을 수 없습니다."
          });
        }

        const userId = socket.data.user.id;

        if (
          chatRoom.menteeId !== userId &&
          chatRoom.mentorId !== userId
        ) {
          return reply({
            success: false,
            message: "읽음 처리 권한이 없습니다."
          });
        }

        // 아직 읽지 않은 상대방 메시지만 읽음 처리
        const readAt = new Date();

        const result = await prisma.chatMessage.updateMany({
          where: {
            chatRoomId,
            senderId: {
              not: userId
            },
            readAt: null
          },
          data: {
            readAt
          }
        });

        // 해당 채팅방의 새 메시지 알림도 읽음 처리
        await prisma.notification.updateMany({
          where: {
            userId,
            chatRoomId,
            type: "CHAT_MESSAGE",
            readAt: null
          },
          data: {
            readAt
          }
        });

        const readData = {
          chatRoomId,
          readerId: userId,
          readAt,
          updatedCount: result.count
        };

        // 같은 채팅방 사용자에게 읽음 상태 전달
        io.to(roomName).emit("chat:read", readData);

        reply({
          success: true,
          message: "메시지를 읽음 처리했습니다.",
          data: readData
        });

      } catch (error) {
        console.error("읽음 처리 오류:", error);

        reply({
          success: false,
          message: "읽음 처리 중 오류가 발생했습니다."
        });
      }
    });


    // 5. 연결 종료
    socket.on("disconnect", () => {
      console.log(
        `채팅 서버 연결 종료: ${socket.data.user.id}`
      );
    });

  });
}

module.exports = initializeChatSocket;

