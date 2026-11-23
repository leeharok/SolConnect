-- CreateTable
CREATE TABLE "MentoringReview" (
    "id" TEXT NOT NULL,
    "chatRoomId" TEXT NOT NULL,
    "menteeId" TEXT NOT NULL,
    "mentorId" TEXT NOT NULL,
    "rating" INTEGER NOT NULL,
    "comment" TEXT,
    "dissatisfactionReason" TEXT,
    "pointsAwarded" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "MentoringReview_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "MentoringReview_chatRoomId_key" ON "MentoringReview"("chatRoomId");

-- CreateIndex
CREATE INDEX "MentoringReview_mentorId_createdAt_idx" ON "MentoringReview"("mentorId", "createdAt");

-- CreateIndex
CREATE INDEX "MentoringReview_menteeId_createdAt_idx" ON "MentoringReview"("menteeId", "createdAt");

-- AddForeignKey
ALTER TABLE "MentoringReview" ADD CONSTRAINT "MentoringReview_chatRoomId_fkey" FOREIGN KEY ("chatRoomId") REFERENCES "ChatRoom"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MentoringReview" ADD CONSTRAINT "MentoringReview_menteeId_fkey" FOREIGN KEY ("menteeId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "MentoringReview" ADD CONSTRAINT "MentoringReview_mentorId_fkey" FOREIGN KEY ("mentorId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
