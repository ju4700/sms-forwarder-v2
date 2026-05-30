import mysql, { type Pool } from "mysql2/promise";

let pool: Pool | null = null;

function buildPool(): Pool {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error("DATABASE_URL is not set");
  }

  const url = new URL(databaseUrl);
  const database = url.pathname.replace("/", "");
  const charset = url.searchParams.get("charset") ?? "utf8mb4";

  return mysql.createPool({
    host: url.hostname,
    port: Number(url.port || 3306),
    user: decodeURIComponent(url.username),
    password: decodeURIComponent(url.password),
    database,
    charset,
    connectionLimit: 10,
    enableKeepAlive: true,
  });
}

export function getPool(): Pool {
  if (pool) {
    return pool;
  }

  const globalPool = (globalThis as { __portalDbPool?: Pool }).__portalDbPool;
  if (globalPool) {
    pool = globalPool;
    return globalPool;
  }

  const created = buildPool();
  (globalThis as { __portalDbPool?: Pool }).__portalDbPool = created;
  pool = created;
  return created;
}

export async function query<T>(sql: string, params: unknown[] = []): Promise<T> {
  const [rows] = await getPool().query(sql, params);
  return rows as T;
}

export async function execute(sql: string, params: unknown[] = []): Promise<void> {
  await getPool().execute(sql, params);
}
