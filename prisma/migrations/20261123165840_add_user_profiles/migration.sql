-- AlterTable
ALTER TABLE "User" ADD COLUMN     "bio" TEXT,
ADD COLUMN     "department" TEXT,
ADD COLUMN     "grade" INTEGER,
ADD COLUMN     "mentorApproved" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "points" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "schoolLevel" "SchoolLevel",
ADD COLUMN     "schoolName" TEXT,
ADD COLUMN     "schoolVerified" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "studentId" TEXT,
ADD COLUMN     "subjects" TEXT[] DEFAULT ARRAY[]::TEXT[];
