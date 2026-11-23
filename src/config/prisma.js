
require("dotenv/config");

const { PrismaPg } = require("@prisma/adapter-pg");
const { PrismaClient } = require("../generated/prisma/client");

// PostgreSQL 연결 설정
const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error("DATABASE_URL이 설정되지 않았습니다.");
}

// Prisma PostgreSQL Adapter 생성
const adapter = new PrismaPg({
  connectionString,
});

// Prisma Client 생성
const prisma = new PrismaClient({
  adapter,
});

module.exports = prisma;
