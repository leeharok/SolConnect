const multer = require("multer");
const path = require("path");
const fs = require("fs");
const crypto = require("crypto");

// 이미지 저장 폴더
const uploadDir = path.join(__dirname, "../../uploads/questions");

// 폴더가 없으면 자동 생성
fs.mkdirSync(uploadDir, { recursive: true });

// 허용할 이미지 형식
const allowedTypes = {
  "image/jpeg": ".jpg",
  "image/png": ".png",
  "image/webp": ".webp"
};

// 저장 방식
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },

  filename: (req, file, cb) => {
    const extension = allowedTypes[file.mimetype];
    const filename = `${crypto.randomUUID()}${extension}`;
    cb(null, filename);
  }
});

// 업로드 설정
const upload = multer({
  storage,
  limits: {
    fileSize: 5 * 1024 * 1024,
    files: 5
  },

  fileFilter: (req, file, cb) => {
    if (!allowedTypes[file.mimetype]) {
      return cb(new Error("JPG, PNG, WEBP 이미지만 업로드할 수 있습니다."));
    }

    cb(null, true);
  }
});

// 질문 이미지 최대 5장
const uploadQuestionImages = upload.array("images", 5);

module.exports = { uploadQuestionImages };
