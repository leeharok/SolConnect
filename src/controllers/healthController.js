
function getHealth(req, res) {
  res.status(200).json({
    success: true,
    message: "나주 멘토링 백엔드 서버가 정상적으로 작동 중입니다!"
  });
}

module.exports = { getHealth };
