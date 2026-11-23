const prisma = require("../config/prisma");

// 내 포인트 잔액 및 적립/사용 내역 조회
async function getMyPointTransactions(req, res) {
  try {
    const page = Number(req.query.page ?? 1);
    const limit = Number(req.query.limit ?? 20);

    if (
      !Number.isInteger(page) ||
      page < 1 ||
      !Number.isInteger(limit) ||
      limit < 1
    ) {
      return res.status(400).json({
        success: false,
        message: "페이지와 조회 개수는 양의 정수여야 합니다."
      });
    }

    const safeLimit = Math.min(limit, 100);

    // 로그인한 사용자 본인의 잔액 조회
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true,
        points: true
      }
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "사용자 정보를 찾을 수 없습니다."
      });
    }

    const where = {
      userId: req.user.id
    };

    const [transactions, totalCount] = await Promise.all([
      prisma.pointTransaction.findMany({
        where,
        orderBy: [
          { createdAt: "desc" },
          { id: "desc" }
        ],
        skip: (page - 1) * safeLimit,
        take: safeLimit,
        select: {
          id: true,
          type: true,
          amount: true,
          description: true,
          source: true,
          createdAt: true
        }
      }),
      prisma.pointTransaction.count({ where })
    ]);

    return res.status(200).json({
      success: true,
      data: {
        balance: user.points,
        transactions,
        pagination: {
          page,
          limit: safeLimit,
          totalCount,
          totalPages: Math.ceil(totalCount / safeLimit)
        }
      }
    });
  } catch (error) {
    console.error("포인트 내역 조회 오류:", error);

    return res.status(500).json({
      success: false,
      message: "포인트 내역을 불러오는 중 오류가 발생했습니다."
    });
  }
}

module.exports = {
  getMyPointTransactions
};
