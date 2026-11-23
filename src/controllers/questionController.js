
const prisma = require("../config/prisma");
const { createNotification } = require("../utils/notificationHelper");

// 질문 등록
async function createQuestion(req, res) {
  try {
    const {
      schoolLevel,
      grade,
      subject,
      curriculum,
      content
    } = req.body || {};

    // 1. 학교급 확인
    const allowedLevels = ["ELEMENTARY", "MIDDLE", "HIGH"];

    if (!allowedLevels.includes(schoolLevel)) {
      return res.status(400).json({
        success: false,
        message: "올바른 학교급을 선택해 주세요."
      });
    }

    // 2. 학년 확인
    const maxGrade = schoolLevel === "ELEMENTARY" ? 6 : 3;

    if (
      !Number.isInteger(grade) ||
      grade < 1 ||
      grade > maxGrade
    ) {
      return res.status(400).json({
        success: false,
        message: "올바른 학년을 입력해 주세요."
      });
    }

    // 3. 과목 확인
    if (
      typeof subject !== "string" ||
      !subject.trim() ||
      subject.trim().length > 50
    ) {
      return res.status(400).json({
        success: false,
        message: "과목을 입력해 주세요."
      });
    }

    // 4. 교육과정 확인
    if (
      curriculum !== undefined &&
      curriculum !== null &&
      (typeof curriculum !== "string" ||
        curriculum.trim().length > 100)
    ) {
      return res.status(400).json({
        success: false,
        message: "교육과정 입력값이 올바르지 않습니다."
      });
    }

    // 5. 질문 내용 확인
    if (
      typeof content !== "string" ||
      !content.trim() ||
      content.trim().length > 5000
    ) {
      return res.status(400).json({
        success: false,
        message: "질문 내용을 입력해 주세요."
      });
    }

    // 6. 질문 등록 및 슬롯 확인
    const MAX_QUESTIONS = 10;
    const MAX_RETRIES = 3;

    let result;

    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      try {
        result = await prisma.$transaction(
          async (tx) => {

            // 현재 사용 중인 질문 슬롯 확인
            const activeCount = await tx.question.count({
              where: {
                menteeId: req.user.id,
                status: {
                  notIn: ["CLOSED", "CANCELED"]
                }
              }
            });

            // 질문 10개 초과 방지
            if (activeCount >= MAX_QUESTIONS) {
              const error = new Error("질문 등록 한도 초과");
              error.code = "QUESTION_LIMIT";
              throw error;
            }

            // 질문 등록
            const question = await tx.question.create({
              data: {
                menteeId: req.user.id,
                schoolLevel,
                grade,
                subject: subject.trim(),
                curriculum: curriculum?.trim() || null,
                content: content.trim()
              }
            });

            return {
              question,
              activeCount: activeCount + 1
            };
          },
          {
            isolationLevel: "Serializable"
          }
        );

        break;

      } catch (error) {

        if (error.code === "QUESTION_LIMIT") {
          return res.status(409).json({
            success: false,
            message: "질문은 최대 10개까지 등록할 수 있습니다."
          });
        }

        // 동시에 여러 질문이 등록될 때 발생하는 충돌 재시도
        if (error.code === "P2034" && attempt < MAX_RETRIES) {
          continue;
        }

        if (error.code === "P2034") {
          return res.status(409).json({
            success: false,
            message: "질문 등록 중 충돌이 발생했습니다. 다시 시도해 주세요."
          });
        }

        throw error;
      }
    }

    // 7. 질문 등록 성공
    return res.status(201).json({
      success: true,
      message: "질문이 등록되었습니다.",
      question: result.question,
      slots: {
        used: result.activeCount,
        limit: MAX_QUESTIONS,
        remaining: MAX_QUESTIONS - result.activeCount
      }
    });

  } catch (error) {
    console.error("질문 등록 오류:", error);

    return res.status(500).json({
      success: false,
      message: "질문 등록 중 서버 오류가 발생했습니다."
    });
  }
}


// 멘토의 질문 목록 조회
async function getAvailableQuestions(req, res) {
  try {
    const {
      schoolLevel,
      grade,
      subject,
      page = "1",
      limit = "10"
    } = req.query;

    // 페이지 설정 확인
    const pageNumber = Number(page);
    const limitNumber = Number(limit);

    if (
      !Number.isInteger(pageNumber) ||
      pageNumber < 1 ||
      !Number.isInteger(limitNumber) ||
      limitNumber < 1 ||
      limitNumber > 20
    ) {
      return res.status(400).json({
        success: false,
        message: "페이지 설정이 올바르지 않습니다."
      });
    }

    // 학교급 필터 확인
    const allowedLevels = [
      "ELEMENTARY",
      "MIDDLE",
      "HIGH"
    ];

    if (
      schoolLevel &&
      !allowedLevels.includes(schoolLevel)
    ) {
      return res.status(400).json({
        success: false,
        message: "올바른 학교급을 선택해 주세요."
      });
    }

    // 학년 필터 확인
    if (grade !== undefined) {
      const gradeNumber = Number(grade);
      const maxGrade = schoolLevel === "ELEMENTARY" ? 6 : 3;

      if (
        !Number.isInteger(gradeNumber) ||
        gradeNumber < 1 ||
        gradeNumber > maxGrade
      ) {
        return res.status(400).json({
          success: false,
          message: "올바른 학년을 입력해 주세요."
        });
      }
    }

    // 과목 필터 확인
    if (
      subject !== undefined &&
      (
        typeof subject !== "string" ||
        !subject.trim() ||
        subject.length > 50
      )
    ) {
      return res.status(400).json({
        success: false,
        message: "과목 검색 조건이 올바르지 않습니다."
      });
    }

    // 검색 조건 구성
    const where = {
      status: "OPEN"
    };

    if (schoolLevel) {
      where.schoolLevel = schoolLevel;
    }

    if (grade !== undefined) {
      where.grade = Number(grade);
    }

    if (subject) {
      where.subject = subject.trim();
    }

    // 질문 목록 및 전체 개수 조회
    const skip = (pageNumber - 1) * limitNumber;

    const [questions, total] = await Promise.all([
      prisma.question.findMany({
        where,
        orderBy: {
          createdAt: "desc"
        },
        skip,
        take: limitNumber,
        select: {
          id: true,
          schoolLevel: true,
          grade: true,
          subject: true,
          curriculum: true,
          content: true,
          status: true,
          createdAt: true,
          images: {
            select: {
              id: true,
              storagePath: true,
              mimeType: true
            }
          }
        }
      }),

      prisma.question.count({ where })
    ]);

    return res.status(200).json({
      success: true,
      message: "질문 목록 조회 성공",
      questions,
      pagination: {
        page: pageNumber,
        limit: limitNumber,
        total,
        totalPages: Math.ceil(total / limitNumber)
      }
    });

  } catch (error) {
    console.error("질문 목록 조회 오류:", error);

    return res.status(500).json({
      success: false,
      message: "질문 목록 조회 중 서버 오류가 발생했습니다."
    });
  }
}


// 멘토의 질문 수락 및 매칭
async function acceptQuestion(req, res) {
  const { id } = req.params;

  const MAX_RETRIES = 3;

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const result = await prisma.$transaction(
        async (tx) => {

          // 1. 질문 존재 여부 확인
          const question = await tx.question.findUnique({
            where: { id },
            select: {
              id: true,
              menteeId: true,
              mentorId: true,
              status: true
            }
          });

          if (!question) {
            const error = new Error("QUESTION_NOT_FOUND");
            error.code = "QUESTION_NOT_FOUND";
            throw error;
          }

          // 2. 이미 다른 멘토가 수락했는지 확인
          if (
            question.status !== "OPEN" ||
            question.mentorId !== null
          ) {
            const error = new Error("QUESTION_ALREADY_TAKEN");
            error.code = "QUESTION_ALREADY_TAKEN";
            throw error;
          }

          // 3. 질문을 원자적으로 수락 처리
          const updated = await tx.question.updateMany({
            where: {
              id,
              status: "OPEN",
              mentorId: null
            },
            data: {
              mentorId: req.user.id,
              status: "MATCHED"
            }
          });

          // 다른 요청이 먼저 처리했다면 실패
          if (updated.count !== 1) {
            const error = new Error("QUESTION_ALREADY_TAKEN");
            error.code = "QUESTION_ALREADY_TAKEN";
            throw error;
          }

          // 4. 채팅방 생성
          const chatRoom = await tx.chatRoom.create({
            data: {
              questionId: question.id,
              menteeId: question.menteeId,
              mentorId: req.user.id
            }
          });

          return {
            questionId: question.id,
            chatRoomId: chatRoom.id,
            mentorId: req.user.id,
            menteeId: question.menteeId,
            status: "MATCHED"
          };
        },
        {
          isolationLevel: "Serializable"
        }
      );

      // 5. 멘티에게 매칭 알림
      await createNotification({
        userId: result.menteeId,
        type: "QUESTION_MATCHED",
        title: "멘토가 매칭됐어요!",
        body: "등록한 질문에 답변할 멘토가 연결됐어요. 채팅을 시작해 보세요.",
        chatRoomId: result.chatRoomId,
        questionId: result.questionId
      });

      // 6. 매칭 성공 응답
      return res.status(201).json({
        success: true,
        message: "멘토 매칭이 완료되었습니다.",
        match: result
      });

    } catch (error) {

      // 존재하지 않는 질문
      if (error.code === "QUESTION_NOT_FOUND") {
        return res.status(404).json({
          success: false,
          message: "질문을 찾을 수 없습니다."
        });
      }

      // 이미 다른 멘토가 수락한 질문
      if (
        error.code === "QUESTION_ALREADY_TAKEN" ||
        error.code === "P2002"
      ) {
        return res.status(409).json({
          success: false,
          message: "이미 다른 멘토가 수락한 질문입니다."
        });
      }

      // 동시 요청으로 인한 트랜잭션 충돌 재시도
      if (error.code === "P2034" && attempt < MAX_RETRIES) {
        continue;
      }

      console.error("질문 수락 오류:", error);

      return res.status(
        error.code === "P2034" ? 409 : 500
      ).json({
        success: false,
        message: error.code === "P2034"
          ? "매칭 요청이 많습니다. 다시 시도해 주세요."
          : "질문 수락 중 서버 오류가 발생했습니다."
      });
    }
  }
}


// 멘티 본인이 등록한 질문 목록 조회
async function getMyQuestions(req, res) {
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
      menteeId: req.user.id
    };

    const [questions, total] = await Promise.all([
      prisma.question.findMany({
        where,
        orderBy: {
          createdAt: "desc"
        },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          schoolLevel: true,
          grade: true,
          subject: true,
          curriculum: true,
          content: true,
          status: true,
          createdAt: true,
          updatedAt: true,
          mentor: {
            select: {
              id: true,
              name: true
            }
          },
          images: {
            select: {
              id: true,
              storagePath: true,
              mimeType: true
            }
          }
        }
      }),

      prisma.question.count({ where })
    ]);

    return res.status(200).json({
      success: true,
      message: "내 질문 목록 조회 성공",
      questions,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      }
    });

  } catch (error) {
    console.error("내 질문 목록 조회 오류:", error);

    return res.status(500).json({
      success: false,
      message: "내 질문 목록을 불러오지 못했습니다."
    });
  }
}

module.exports = {
  createQuestion,
  getAvailableQuestions,
  getMyQuestions,
  acceptQuestion
};