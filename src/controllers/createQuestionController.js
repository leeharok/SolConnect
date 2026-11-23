const prisma = require("../config/prisma");
const fs = require("fs");

async function removeUploadedFiles(files) {
  await Promise.all(
    (files || []).map((file) =>
      fs.promises.unlink(file.path).catch(() => {})
    )
  );
}

// 멘티 질문 등록
async function createQuestion(req, res) {
  const files = req.files || [];

  // 오류 발생 시 업로드된 파일 정리
  async function fail(status, message) {
    await removeUploadedFiles(files);
    return res.status(status).json({
      success: false,
      message
    });
  }

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
      return await fail(400, "올바른 학교급을 선택해 주세요.");
    }

    // 2. 학년 확인
    const gradeNumber = Number(grade);
    const maxGrade = schoolLevel === "ELEMENTARY" ? 6 : 3;

    if (
      !Number.isInteger(gradeNumber) ||
      gradeNumber < 1 ||
      gradeNumber > maxGrade
    ) {
      return await fail(400, "올바른 학년을 입력해 주세요.");
    }

    // 3. 과목 확인
    if (
      typeof subject !== "string" ||
      !subject.trim() ||
      subject.trim().length > 50
    ) {
      return await fail(400, "과목을 입력해 주세요.");
    }

    // 4. 교육과정 확인
    if (
      curriculum !== undefined &&
      curriculum !== null &&
      (typeof curriculum !== "string" ||
        curriculum.trim().length > 100)
    ) {
      return await fail(400, "교육과정 입력값이 올바르지 않습니다.");
    }

    // 5. 질문 내용 확인 (선택 입력)
    if (
      content !== undefined &&
      content !== null &&
      typeof content !== "string"
    ) {
      return await fail(400, "질문 내용이 올바르지 않습니다.");
    }

    const cleanContent = content?.trim() || "";

    if (cleanContent.length > 5000) {
      return await fail(400, "질문 내용은 5000자까지 입력할 수 있습니다.");
    }

    // 이미지나 텍스트 중 하나는 반드시 필요
    if (!cleanContent && files.length === 0) {
      return await fail(
        400,
        "문제 사진을 첨부하거나 질문 내용을 입력해 주세요."
      );
    }

    // 6. 질문 등록 및 슬롯 확인
    const MAX_QUESTIONS = 10;
    const MAX_RETRIES = 3;

    let result;

    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      try {
        result = await prisma.$transaction(
          async (tx) => {
            const activeCount = await tx.question.count({
              where: {
                menteeId: req.user.id,
                status: {
                  notIn: ["CLOSED", "CANCELED"]
                }
              }
            });

            if (activeCount >= MAX_QUESTIONS) {
              const error = new Error("QUESTION_LIMIT");
              error.code = "QUESTION_LIMIT";
              throw error;
            }

            const question = await tx.question.create({
              data: {
                menteeId: req.user.id,
                schoolLevel,
                grade: gradeNumber,
                subject: subject.trim(),
                curriculum: curriculum?.trim() || null,
                content: cleanContent || null,

                // 이미지 경로도 질문과 함께 저장
                images: {
                  create: files.map((file) => ({
                    storagePath: `/uploads/questions/${file.filename}`,
                    mimeType: file.mimetype
                  }))
                }
              },
              include: {
                images: true
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
          return await fail(
            409,
            "질문은 최대 10개까지 등록할 수 있습니다."
          );
        }

        if (error.code === "P2034" && attempt < MAX_RETRIES) {
          continue;
        }

        if (error.code === "P2034") {
          return await fail(
            409,
            "질문 등록 중 충돌이 발생했습니다. 다시 시도해 주세요."
          );
        }

        throw error;
      }
    }

    // 7. 등록 성공
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

    return await fail(
      500,
      "질문 등록 중 서버 오류가 발생했습니다."
    );
  }
}

module.exports = { createQuestion };
