import { execute, query } from "@/lib/db";

let initialized = false;

export async function ensureSchema(): Promise<void> {
  if (initialized) {
    return;
  }

  await execute(`
    CREATE TABLE IF NOT EXISTS devices (
      id VARCHAR(36) PRIMARY KEY,
      secret_hash VARCHAR(255) NOT NULL,
      pin_hash VARCHAR(255) NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      last_seen_at TIMESTAMP NULL,
      pin_updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);

  const pinLookupColumn = await query<{ COLUMN_NAME: string }[]>(
    "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'devices' AND COLUMN_NAME = 'pin_lookup'",
  );
  if (pinLookupColumn.length === 0) {
    await execute("ALTER TABLE devices ADD COLUMN pin_lookup CHAR(64) NULL");
  }

  const pinLookupIndex = await query<{ INDEX_NAME: string }[]>(
    "SELECT INDEX_NAME FROM INFORMATION_SCHEMA.STATISTICS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'devices' AND INDEX_NAME = 'idx_devices_pin_lookup'",
  );
  if (pinLookupIndex.length === 0) {
    await execute("CREATE UNIQUE INDEX idx_devices_pin_lookup ON devices (pin_lookup)");
  }

  await execute(`
    CREATE TABLE IF NOT EXISTS pairing_sessions (
      id VARCHAR(36) PRIMARY KEY,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      expires_at TIMESTAMP NOT NULL,
      claimed_at TIMESTAMP NULL,
      claimed_device_id VARCHAR(36) NULL,
      INDEX idx_pairing_expires (expires_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);

  await execute(`
    CREATE TABLE IF NOT EXISTS messages (
      id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
      device_id VARCHAR(36) NOT NULL,
      address VARCHAR(64) NOT NULL,
      body TEXT NOT NULL,
      direction ENUM('incoming', 'outgoing') NOT NULL,
      sent_at TIMESTAMP NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      INDEX idx_messages_device_time (device_id, sent_at)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  `);

  initialized = true;
}
