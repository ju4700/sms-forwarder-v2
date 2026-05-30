import { execute } from "@/lib/db";

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
