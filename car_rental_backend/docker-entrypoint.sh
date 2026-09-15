#!/bin/sh
set -e

# Support decoupled migration execution in distributed/multi-replica deployments
if [ "$AUTO_MIGRATE" = "true" ]; then
  echo "[DriveGo Entrypoint] Applying database migrations via Prisma (AUTO_MIGRATE=true)..."
  npx prisma migrate deploy
  echo "[DriveGo Entrypoint] Prisma migrations completed."
else
  echo "[DriveGo Entrypoint] Skipping in-container migration deploy (orchestrated migration job pattern enabled)."
fi

echo "[DriveGo Entrypoint] Starting application..."
exec "$@"