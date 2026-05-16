CREATE TABLE IF NOT EXISTS "reports" (
    "id" TEXT NOT NULL,
    "reporterId" TEXT NOT NULL,
    "targetId" TEXT NOT NULL,
    "targetType" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "isResolved" BOOLEAN NOT NULL DEFAULT false,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "reports_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "reports" ADD COLUMN IF NOT EXISTS "isResolved" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "reports" ADD COLUMN IF NOT EXISTS "resolvedAt" TIMESTAMP(3);

ALTER TABLE "reports" ADD CONSTRAINT "reports_reporterId_fkey"
    FOREIGN KEY ("reporterId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
