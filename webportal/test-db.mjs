import { createPool } from "mysql2/promise";
import bcrypt from "bcryptjs";

const pool = createPool("mysql://linkupbd_ju4700:KYtVnbZ3ebYF5c_@49.12.82.48:3306/linkupbd_smsdb?charset=utf8mb4");

async function main() {
  const [rows] = await pool.query("SELECT id, pin_hash FROM devices ORDER BY created_at DESC LIMIT 5");
  console.log("Devices:", rows);
  pool.end();
}

main().catch(console.error);
