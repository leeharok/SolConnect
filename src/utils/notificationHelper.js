const prisma = require("../config/prisma");

// 알림 저장 실패가 주요 기능에 영향을 주지 않도록 분리
async function createNotification({
  userId,
  type,
  title,
  body,
  chatRoomId = null,
  questionId = null
}) {
  try {
    return await prisma.notification.create({
      data: {
        userId,
        type,
        title,
        body,
        chatRoomId,
        questionId
      }
    });
  } catch (error) {
    console.error("알림 생성 오류:", error);
    return null;
  }
}

module.exports = {
  createNotification
};
