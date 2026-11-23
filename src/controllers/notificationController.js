const prisma = require("../config/prisma");

// 내 알림 목록 조회
async function getMyNotifications(req, res) {
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
      userId: req.user.id
    };

    const [notifications, total, unreadCount] = await Promise.all([
      prisma.notification.findMany({
        where,
        orderBy: {
          createdAt: "desc"
        },
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          type: true,
          title: true,
          body: true,
          chatRoomId: true,
          questionId: true,
          readAt: true,
          createdAt: true
        }
      }),

      prisma.notification.count({
        where
      }),

      prisma.notification.count({
        where: {
          ...where,
          readAt: null
        }
      })
    ]);

    return res.status(200).json({
      success: true,
      message: "알림 목록 조회 성공",
      notifications,
      unreadCount,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit)
      }
    });

  } catch (error) {
    console.error("알림 목록 조회 오류:", error);

    return res.status(500).json({
      success: false,
      message: "알림 목록을 불러오지 못했습니다."
    });
  }
}


// 내 안 읽은 알림 개수 조회
async function getUnreadNotificationCount(req, res) {
  try {
    const unreadCount = await prisma.notification.count({
      where: {
        userId: req.user.id,
        readAt: null
      }
    });

    return res.status(200).json({
      success: true,
      unreadCount
    });

  } catch (error) {
    console.error("안 읽은 알림 개수 조회 오류:", error);

    return res.status(500).json({
      success: false,
      message: "안 읽은 알림 개수를 불러오지 못했습니다."
    });
  }
}


// 알림 하나 읽음 처리
async function markNotificationAsRead(req, res) {
  try {
    const { id } = req.params;

    const notification = await prisma.notification.findFirst({
      where: {
        id,
        userId: req.user.id
      },
      select: {
        id: true,
        readAt: true
      }
    });

    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "알림을 찾을 수 없습니다."
      });
    }

    if (!notification.readAt) {
      await prisma.notification.updateMany({
        where: {
          id,
          userId: req.user.id,
          readAt: null
        },
        data: {
          readAt: new Date()
        }
      });
    }

    return res.status(200).json({
      success: true,
      message: "알림을 읽음 처리했습니다."
    });

  } catch (error) {
    console.error("알림 읽음 처리 오류:", error);

    return res.status(500).json({
      success: false,
      message: "알림 읽음 처리 중 서버 오류가 발생했습니다."
    });
  }
}


// 내 알림 전체 읽음 처리
async function markAllNotificationsAsRead(req, res) {
  try {
    const result = await prisma.notification.updateMany({
      where: {
        userId: req.user.id,
        readAt: null
      },
      data: {
        readAt: new Date()
      }
    });

    return res.status(200).json({
      success: true,
      message: "모든 알림을 읽음 처리했습니다.",
      updatedCount: result.count
    });

  } catch (error) {
    console.error("전체 알림 읽음 처리 오류:", error);

    return res.status(500).json({
      success: false,
      message: "전체 알림 읽음 처리 중 서버 오류가 발생했습니다."
    });
  }
}

module.exports = {
  getMyNotifications,
  getUnreadNotificationCount,
  markNotificationAsRead,
  markAllNotificationsAsRead
};
