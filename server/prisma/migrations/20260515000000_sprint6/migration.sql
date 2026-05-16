-- AlterTable: add searchStatus to seeker_profiles
ALTER TABLE "seeker_profiles" ADD COLUMN "searchStatus" TEXT NOT NULL DEFAULT 'ACTIVE';
