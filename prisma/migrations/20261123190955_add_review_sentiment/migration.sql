-- CreateEnum
CREATE TYPE "ReviewSentiment" AS ENUM ('SATISFIED', 'UNSATISFIED');

-- AlterTable
ALTER TABLE "MentoringReview" ADD COLUMN     "sentiment" "ReviewSentiment",
ALTER COLUMN "rating" DROP NOT NULL;
