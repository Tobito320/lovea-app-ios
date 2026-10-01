// Stand-in für Cloudflare D1 in Node-Tests, auf node:sqlite (inkl. FTS5).
import { DatabaseSync } from "node:sqlite";

export function fakeD1(schema) {
  const db = new DatabaseSync(":memory:");
  if (schema) db.exec(schema);
  const stmt = (sql, werte = []) => ({
    bind: (...w) => stmt(sql, w),
    first: async () => db.prepare(sql).get(...werte) ?? null,
    all: async () => ({ results: db.prepare(sql).all(...werte) }),
    run: async () => { db.prepare(sql).run(...werte); return { success: true }; },
  });
  return { prepare: (sql) => stmt(sql), exec: async (sql) => db.exec(sql), roh: db };
}
