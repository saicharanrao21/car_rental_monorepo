#!/bin/sh
set -e

echo "[DriveGo Entrypoint] Applying database migrations via Prisma..."
npx prisma migrate deploy

echo "[DriveGo Entrypoint] Starting application..."
exec "$@"