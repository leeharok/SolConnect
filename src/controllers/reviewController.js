const prisma = require("../config/prisma");
const { createNotification } = require("../utils/notificationHelper");

const REVIEW_POINTS = 200;

// 멘티 후기 제출
async function submitReview(req, res) {
  try {
    const { chatRoomId } = req.params;
    const { sentiment, comment, dissatisfactionReason } = req.body || {};

    // 1. 만족/불만족 검증
    const allowedSentiments = ["SATISFIED", "UNSATISFIED"];

    if (!allowedSentiments.includes(sentiment)) {
      return res.status(400).json({
        success: false,
        message: "만족 또는 불만족을 선택해 주세요."
      });
    }

    // 2. 후기 내용 검증 (선택)
    if (
      comment !== undefined &&
      comment !== null &&
      (typeof comment !== "string" || comment.trim().length > 5000)
    ) {
      return res.status(400).json({
        success: false,
        message: "후기는 5000자까지 작성할 수 있습니다."
      });
    }

    const cleanComment = comment?.trim() || "";
    const cleanReason = dissatisfactionReason?.trim() || "";

    if (
      dissatisfactionReason !== undefined &&
      dissatisfactionReason !== null &&
      (typeof dissatisfactionReason !== "string" ||
        dissatisfactionReason.trim().length > 5000)
    ) {
      return res.status(400).json({
        success: false,
        message: "불만족 사유는 5000자까지 작성할 수 있습니다."
      });
    }

    if (
      sentiment === "UNSATISFIED" &&
      cleanReason.length < 100
    ) {
      return res.status(400).json({
        success: false,
        message: "불만족 사유를 100자 이상 작성해 주세요."
      });
    }

    // 만족/불만족 관계없이 동일하게 200P 지급
    const pointsAwarded = REVIEW_POINTS;

    // 3. 후기 등록, 질문 종료, 포인트 지급을 하나의 트랜잭션으로 처리
    const result = await prisma.$transaction(
      async (tx) => {
        const chatRoom = await tx.chatRoom.findUnique({
          where: { id: chatRoomId },
          select: {
            id: true,
            menteeId: true,
            mentorId: true,
            status: true,
            question: {
              select: {
                id: true,
                status: true,
                mentorId: true
              }
            }
          }
        });

        if (!chatRoom) {
          const error = new Error("CHAT_NOT_FOUND");
          error.code = "CHAT_NOT_FOUND";
          throw error;
        }

        // 해당 채팅방의 멘티만 후기 작성 가능
        if (chatRoom.menteeId !== req.user.id) {
          const error = new Error("NOT_CHAT_MENTEE");
          error.code = "NOT_CHAT_MENTEE";
          throw error;
        }

        // 상담 종료 여부 확인
        if (chatRoom.status !== "COMPLETED") {
          const error = new Error("CHAT_NOT_COMPLETED");
          error.code = "CHAT_NOT_COMPLETED";
          throw error;
        }

        // 질문 상태 확인
        if (
          chatRoom.question.status !== "WAITING_REVIEW" ||
          chatRoom.question.mentorId !== chatRoom.mentorId
        ) {
          const error = new Error("QUESTION_STATE_CONFLICT");
          error.code = "QUESTION_STATE_CONFLICT";
          throw error;
        }

        // 중복 후기 방지
        const existingReview = await tx.mentoringReview.findUnique({
          where: { chatRoomId }
        });

        if (existingReview) {
          const error = new Error("REVIEW_ALREADY_SUBMITTED");
          error.code = "REVIEW_ALREADY_SUBMITTED";
          throw error;
        }

        // 질문 종료 처리 및 질문 슬롯 반환
        const updatedQuestion = await tx.question.updateMany({
          where: {
            id: chatRoom.question.id,
            mentorId: chatRoom.mentorId,
            status: "WAITING_REVIEW"
          },
          data: {
            status: "CLOSED"
          }
        });

        if (updatedQuestion.count !== 1) {
          const error = new Error("QUESTION_STATE_CONFLICT");
          error.code = "QUESTION_STATE_CONFLICT";
          throw error;
        }

        // 후기 저장
        const review = await tx.mentoringReview.create({
          data: {
            chatRoomId,
            menteeId: chatRoom.menteeId,
            mentorId: chatRoom.mentorId,
            sentiment,
            rating: null,
            comment: sentiment === "SATISFIED"
              ? cleanComment || null
              : null,
            dissatisfactionReason: sentiment === "UNSATISFIED"
              ? cleanReason
              : null,
            pointsAwarded
          }
        });

        // 멘토에게 포인트 지급
        const mentor = await tx.user.update({
          where: {
            id: chatRoom.mentorId
          },
          data: {
            points: {
              increment: pointsAwarded
            }
          },
          select: {
            id: true,
            points: true
          }
        });

        // 포인트 적립 내역 기록
        await tx.pointTransaction.create({
          data: {
            userId: chatRoom.mentorId,
            type: "EARNED",
            amount: pointsAwarded,
            description: "멘토링 후기 보상",
            source: "MENTORING_REVIEW",
            sourceId: review.id
          }
        });

        return {
          review,
          mentorPoints: mentor.points,
          questionId: chatRoom.question.id,
          questionStatus: "CLOSED"
        };
      },
      {
        isolationLevel: "Serializable"
      }
    );

    await createNotification({
      userId: result.review.mentorId,
      type: "REVIEW_SUBMITTED",
      title: "멘토링 후기가 등록됐어요",
      body: "멘티가 후기를 제출했어요. 200P가 적립되었습니다.",
      chatRoomId,
      questionId: result.questionId
    });

    return res.status(201).json({
      success: true,
      message: "후기가 등록되고 멘토에게 200P가 지급되었습니다.",
      data: result
    });

  } catch (error) {
    console.error("후기 등록 오류:", error);

    if (error.code === "CHAT_NOT_FOUND") {
      return res.status(404).json({
        success: false,
        message: "채팅방을 찾을 수 없습니다."
      });
    }

    if (error.code === "NOT_CHAT_MENTEE") {
      return res.status(403).json({
        success: false,
        message: "후기를 작성할 권한이 없습니다."
      });
    }

    if (error.code === "CHAT_NOT_COMPLETED") {
      return res.status(409).json({
        success: false,
        message: "멘티가 문제 해결을 확인한 후 후기를 작성할 수 있습니다."
      });
    }

    if (
      error.code === "REVIEW_ALREADY_SUBMITTED" ||
      error.code === "P2002"
    ) {
      return res.status(409).json({
        success: false,
        message: "이미 후기를 제출한 멘토링입니다."
      });
    }

    if (
      error.code === "QUESTION_STATE_CONFLICT" ||
      error.code === "P2034"
    ) {
      return res.status(409).json({
        success: false,
        message: "질문 상태가 변경되었습니다. 다시 확인해 주세요."
      });
    }

    return res.status(500).json({
      success: false,
      message: "후기 등록 중 서버 오류가 발생했습니다."
    });
  }
}


// 멘토가 받은 후기 목록 조회
async function getReceivedReviews(req, res) {
  try {
    const page = Number(req.query.page || 1);
    const limit = Number(req.query.limit || 20);

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

    const where = {
      mentorId: req.user.id
    };

    const [reviews, total, satisfiedCount, unsatisfiedCount] =
      await Promise.all([
        prisma.mentoringReview.findMany({
          where,
          orderBy: {
            createdAt: "desc"
          },
          skip: (page - 1) * limit,
          take: limit,
          select: {
            id: true,
            sentiment: true,
            comment: true,
            dissatisfactionReason: true,
            pointsAwarded: true,
            createdAt: true,
            mentee: {
              select: {
                name: true
              }
            },
            chatRoom: {
              select: {
                question: {
                  select: {
                    id: true,
                    subject: true,
                    schoolLevel: true,
                    grade: true
                  }
                }
              }
            }
          }
        }),

        prisma.mentoringReview.count({ where }),

        prisma.mentoringReview.count({
          where: {
            ...where,
            sentiment: "SATISFIED"
          }
        }),

        prisma.mentoringReview.count({
          where: {
            ...where,
            sentiment: "UNSATISFIED"
          }
        })
      ]);

    const formattedReviews = reviews.map((review) => ({
      id: review.id,
      sentiment: review.sentiment,
      comment: review.comment,
      dissatisfactionReason: review.dissatisfactionReason,
      pointsAwarded: review.pointsAwarded,
      createdAt: review.createdAt,
      menteeName: review.mentee.name,
      question: review.chatRoom.question
    }));

    return res.status(200).json({
      success: true,
      message: "받은 후기 목록 조회 성공",
      reviews: formattedReviews,
      summary: {
        total,
        satisfiedCount,
        unsatisfiedCount
      },
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      }
    });

  } catch (error) {
    console.error("받은 후기 목록 조회 오류:", error);

    return res.status(500).json({
      success: false,
      message: "받은 후기 목록을 불러오지 못했습니다."
    });
  }
}

module.exports = {
  submitReview,
  getReceivedReviews
};
