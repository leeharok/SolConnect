
const prisma = require("../config/prisma");
const { createNotification } = require("../utils/notificationHelper");

// 채팅 기록 조회
async function getChatMessages(req, res) {
  try {
    const { chatRoomId } = req.params;

    const page = Number(req.query.page || 1);
    const limit = Number(req.query.limit || 20);

    // 1. 페이지 설정 확인
    if (
      !Number.isInteger(page) ||
      page < 1 ||
      !Number.isInteger(limit) ||
      limit < 1 ||
      limit > 50
    ) {
      return res.status(400).json({
        success: false,
        message: "조회 페이지 설정이 올바르지 않습니다."
      });
    }

    // 2. 채팅방 조회
    const chatRoom = await prisma.chatRoom.findUnique({
      where: {
        id: chatRoomId
      },
      select: {
        id: true,
        menteeId: true,
        mentorId: true
      }
    });

    if (!chatRoom) {
      return res.status(404).json({
        success: false,
        message: "채팅방을 찾을 수 없습니다."
      });
    }

    // 3. 채팅방 참여자 확인
    const userId = req.user.id;

    if (
      chatRoom.menteeId !== userId &&
      chatRoom.mentorId !== userId
    ) {
      return res.status(403).json({
        success: false,
        message: "채팅 기록을 조회할 권한이 없습니다."
      });
    }

    // 4. 메시지 조회
    const where = {
      chatRoomId
    };

    const [messages, total] = await Promise.all([
      prisma.chatMessage.findMany({
        where,
        orderBy: [
          { createdAt: "desc" },
          { id: "desc" }
        ],
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          chatRoomId: true,
          senderId: true,
          content: true,
          readAt: true,
          createdAt: true,
          sender: {
            select: {
              name: true
            }
          }
        }
      }),

      prisma.chatMessage.count({
        where
      })
    ]);

    // 5. 오래된 메시지부터 표시
    const formattedMessages = messages
      .reverse()
      .map((message) => ({
        id: message.id,
        chatRoomId: message.chatRoomId,
        senderId: message.senderId,
        senderName: message.sender.name,
        content: message.content,
        readAt: message.readAt,
        createdAt: message.createdAt
      }));

    // 6. 조회 결과 반환
    return res.status(200).json({
      success: true,
      message: "채팅 기록 조회 성공",
      messages: formattedMessages,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      }
    });

  } catch (error) {
    console.error("채팅 기록 조회 오류:", error);

    return res.status(500).json({
      success: false,
      message: "채팅 기록 조회 중 서버 오류가 발생했습니다."
    });
  }
}



// 로그인한 사용자의 진행 중인 채팅방 목록 조회
async function getMyChatRooms(req, res) {
  try {
    const chatRooms = await prisma.chatRoom.findMany({
      where: {
        OR: [
          // 진행 중인 채팅방: 멘토와 멘티 모두 조회
          {
            status: {
              in: ["ACTIVE", "COMPLETION_REQUESTED"]
            },
            menteeId: req.user.id
          },
          {
            status: {
              in: ["ACTIVE", "COMPLETION_REQUESTED"]
            },
            mentorId: req.user.id
          },
          // 상담 종료 후 후기 미작성 채팅방: 멘티만 조회
          {
            status: "COMPLETED",
            menteeId: req.user.id,
            question: {
              is: {
                status: "WAITING_REVIEW"
              }
            }
          }
        ]
      },
      orderBy: {
        updatedAt: "desc"
      },
      select: {
        id: true,
        status: true,
        createdAt: true,
        updatedAt: true,
        menteeId: true,
        mentorId: true,

        mentee: {
          select: {
            id: true,
            name: true
          }
        },

        mentor: {
          select: {
            id: true,
            name: true
          }
        },

        question: {
          select: {
            id: true,
            subject: true,
            schoolLevel: true,
            grade: true,
            status: true,
            content: true,
            images: {
              select: {
                id: true,
                storagePath: true,
                mimeType: true
              }
            }
          }
        },

        messages: {
          orderBy: {
            createdAt: "desc"
          },
          take: 1,
          select: {
            id: true,
            senderId: true,
            content: true,
            readAt: true,
            createdAt: true
          }
        }
      }
    });

    const formattedRooms = chatRooms.map((room) => {
      const isMentee = room.menteeId === req.user.id;
      const partner = isMentee ? room.mentor : room.mentee;

      return {
        id: room.id,
        status: room.status,
        createdAt: room.createdAt,
        updatedAt: room.updatedAt,
        partner: {
          id: partner.id,
          name: partner.name
        },
        question: room.question,
        lastMessage: room.messages[0] || null
      };
    });

    return res.status(200).json({
      success: true,
      message: "채팅방 목록 조회 성공",
      chatRooms: formattedRooms
    });

  } catch (error) {
    console.error("채팅방 목록 조회 오류:", error);

    return res.status(500).json({
      success: false,
      message: "채팅방 목록을 불러오지 못했습니다."
    });
  }
}


// 멘토가 풀이 전달 완료를 요청
async function requestChatCompletion(req, res) {
  try {
    const { chatRoomId } = req.params;

    const result = await prisma.$transaction(
      async (tx) => {
        const chatRoom = await tx.chatRoom.findUnique({
          where: { id: chatRoomId },
          select: {
            id: true,
            menteeId: true,
            mentorId: true,
            status: true
          }
        });

        if (!chatRoom) {
          const error = new Error("CHAT_NOT_FOUND");
          error.code = "CHAT_NOT_FOUND";
          throw error;
        }

        if (chatRoom.mentorId !== req.user.id) {
          const error = new Error("NOT_CHAT_MENTOR");
          error.code = "NOT_CHAT_MENTOR";
          throw error;
        }

        if (chatRoom.status !== "ACTIVE") {
          const error = new Error("CHAT_NOT_ACTIVE");
          error.code = "CHAT_NOT_ACTIVE";
          throw error;
        }

        const updated = await tx.chatRoom.updateMany({
          where: {
            id: chatRoomId,
            mentorId: req.user.id,
            status: "ACTIVE"
          },
          data: {
            status: "COMPLETION_REQUESTED"
          }
        });

        if (updated.count !== 1) {
          const error = new Error("CHAT_NOT_ACTIVE");
          error.code = "CHAT_NOT_ACTIVE";
          throw error;
        }

        return {
          chatRoomId,
          menteeId: chatRoom.menteeId,
          mentorId: chatRoom.mentorId,
          chatStatus: "COMPLETION_REQUESTED"
        };
      },
      {
        isolationLevel: "Serializable"
      }
    );

    await createNotification({
      userId: result.menteeId,
      type: "COMPLETION_REQUESTED",
      title: "풀이 전달 완료 요청",
      body: "멘토가 풀이 전달을 완료했어요. 문제가 해결되었는지 확인해 주세요.",
      chatRoomId
    });

    const io = req.app.get("io");

    if (io) {
      io.to(`chat:${chatRoomId}`).emit(
        "chat:completion-requested",
        {
          chatRoomId,
          status: "COMPLETION_REQUESTED"
        }
      );
    }

    return res.status(200).json({
      success: true,
      message: "풀이 전달 완료를 요청했습니다. 멘티의 확인을 기다립니다.",
      data: result
    });

  } catch (error) {
    console.error("풀이 전달 완료 요청 오류:", error);

    if (error.code === "CHAT_NOT_FOUND") {
      return res.status(404).json({
        success: false,
        message: "채팅방을 찾을 수 없습니다."
      });
    }

    if (error.code === "NOT_CHAT_MENTOR") {
      return res.status(403).json({
        success: false,
        message: "완료 요청 권한이 없습니다."
      });
    }

    if (
      error.code === "CHAT_NOT_ACTIVE" ||
      error.code === "P2034"
    ) {
      return res.status(409).json({
        success: false,
        message: "채팅방 상태가 변경되었거나 이미 완료 요청이 진행 중입니다."
      });
    }

    return res.status(500).json({
      success: false,
      message: "완료 요청 중 서버 오류가 발생했습니다."
    });
  }
}


// 멘티가 문제 해결 여부를 확인
async function confirmChatCompletion(req, res) {
  try {
    const { chatRoomId } = req.params;
    const { resolved } = req.body || {};

    if (typeof resolved !== "boolean") {
      return res.status(400).json({
        success: false,
        message: "문제 해결 여부를 선택해 주세요."
      });
    }

    const result = await prisma.$transaction(
      async (tx) => {
        const chatRoom = await tx.chatRoom.findUnique({
          where: { id: chatRoomId },
          select: {
            id: true,
            questionId: true,
            menteeId: true,
            mentorId: true,
            status: true
          }
        });

        if (!chatRoom) {
          const error = new Error("CHAT_NOT_FOUND");
          error.code = "CHAT_NOT_FOUND";
          throw error;
        }

        if (chatRoom.menteeId !== req.user.id) {
          const error = new Error("NOT_CHAT_MENTEE");
          error.code = "NOT_CHAT_MENTEE";
          throw error;
        }

        if (chatRoom.status !== "COMPLETION_REQUESTED") {
          const error = new Error("COMPLETION_NOT_REQUESTED");
          error.code = "COMPLETION_NOT_REQUESTED";
          throw error;
        }

        if (!resolved) {
          const updated = await tx.chatRoom.updateMany({
            where: {
              id: chatRoomId,
              menteeId: req.user.id,
              status: "COMPLETION_REQUESTED"
            },
            data: {
              status: "ACTIVE"
            }
          });

          if (updated.count !== 1) {
            const error = new Error("COMPLETION_NOT_REQUESTED");
            error.code = "COMPLETION_NOT_REQUESTED";
            throw error;
          }

          return {
            chatRoomId,
            resolved: false,
            chatStatus: "ACTIVE"
          };
        }

        const completedAt = new Date();

        const updatedRoom = await tx.chatRoom.updateMany({
          where: {
            id: chatRoomId,
            menteeId: req.user.id,
            status: "COMPLETION_REQUESTED"
          },
          data: {
            status: "COMPLETED",
            completedAt
          }
        });

        if (updatedRoom.count !== 1) {
          const error = new Error("COMPLETION_NOT_REQUESTED");
          error.code = "COMPLETION_NOT_REQUESTED";
          throw error;
        }

        const updatedQuestion = await tx.question.updateMany({
          where: {
            id: chatRoom.questionId,
            mentorId: chatRoom.mentorId,
            status: {
              in: ["MATCHED", "IN_PROGRESS"]
            }
          },
          data: {
            status: "WAITING_REVIEW"
          }
        });

        if (updatedQuestion.count !== 1) {
          const error = new Error("QUESTION_STATE_CONFLICT");
          error.code = "QUESTION_STATE_CONFLICT";
          throw error;
        }

        return {
          chatRoomId,
          questionId: chatRoom.questionId,
          resolved: true,
          chatStatus: "COMPLETED",
          questionStatus: "WAITING_REVIEW",
          completedAt
        };
      },
      {
        isolationLevel: "Serializable"
      }
    );

    const io = req.app.get("io");

    if (io) {
      if (result.resolved) {
        io.to(`chat:${chatRoomId}`).emit(
          "chat:completed",
          {
            chatRoomId,
            questionId: result.questionId,
            status: "COMPLETED",
            completedAt: result.completedAt
          }
        );
      } else {
        io.to(`chat:${chatRoomId}`).emit(
          "chat:completion-response",
          {
            chatRoomId,
            resolved: false,
            status: "ACTIVE"
          }
        );
      }
    }

    return res.status(200).json({
      success: true,
      message: resolved
        ? "문제 해결이 확인되었습니다. 후기를 작성해 주세요."
        : "추가 설명 요청이 전달되었습니다. 상담을 계속할 수 있습니다.",
      data: result
    });

  } catch (error) {
    console.error("문제 해결 확인 오류:", error);

    if (error.code === "CHAT_NOT_FOUND") {
      return res.status(404).json({
        success: false,
        message: "채팅방을 찾을 수 없습니다."
      });
    }

    if (error.code === "NOT_CHAT_MENTEE") {
      return res.status(403).json({
        success: false,
        message: "해결 여부를 확인할 권한이 없습니다."
      });
    }

    if (
      error.code === "COMPLETION_NOT_REQUESTED" ||
      error.code === "QUESTION_STATE_CONFLICT" ||
      error.code === "P2034"
    ) {
      return res.status(409).json({
        success: false,
        message: "완료 요청 상태가 변경되었습니다. 다시 확인해 주세요."
      });
    }

    return res.status(500).json({
      success: false,
      message: "문제 해결 확인 중 서버 오류가 발생했습니다."
    });
  }
}


// 로그인한 사용자의 안 읽은 채팅 메시지 수 조회
async function getUnreadChatCount(req, res) {
  try {
    const unreadCount = await prisma.chatMessage.count({
      where: {
        readAt: null,
        senderId: {
          not: req.user.id
        },
        chatRoom: {
          is: {
            OR: [
              { menteeId: req.user.id },
              { mentorId: req.user.id }
            ]
          }
        }
      }
    });

    return res.status(200).json({
      success: true,
      message: "안 읽은 메시지 수 조회 성공",
      unreadCount
    });

  } catch (error) {
    console.error("안 읽은 메시지 수 조회 오류:", error);

    return res.status(500).json({
      success: false,
      message: "안 읽은 메시지 수를 불러오지 못했습니다."
    });
  }
}

module.exports = {
  getMyChatRooms,
  getChatMessages,
  getUnreadChatCount,
  requestChatCompletion,
  confirmChatCompletion
};
