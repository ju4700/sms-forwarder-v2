import { execute } from "@/lib/db";

const RETENTION_DAYS = 30;
let lastCleanupAt = 0;

export async function cleanupOldMessages(): Promise<void> {
  const now = Date.now();
  if (now - lastCleanupAt < 12 * 60 * 60 * 1000) {
    return;
  }

  lastCleanupAt = now;
  await execute(
    `DELETE FROM messages WHERE sent_at < (NOW() - INTERVAL ${RETENTION_DAYS} DAY)`,
  );
}
