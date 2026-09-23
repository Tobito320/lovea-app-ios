// Tiny in-memory stand-in for Workers' `ctx.storage.sql`, backed by Node's
// built-in node:sqlite. Real SQLite semantics, just not Durable Object
// storage. exec(query, ...bindings) mimics the subset of the Workers cursor
// API this project uses: .toArray() and .one().
import { DatabaseSync } from "node:sqlite";

export function fakeSql() {
  const db = new DatabaseSync(":memory:");
  return {
    exec(query, ...bindings) {
      const stmt = db.prepare(query);
      if (/^\s*(select|pragma)/i.test(query)) {
        const rows = stmt.all(...bindings);
        return {
          toArray: () => rows,
          one: () => {
            if (rows.length !== 1) throw new Error(`expected exactly one row, got ${rows.length}`);
            return rows[0];
          },
          [Symbol.iterator]: () => rows[Symbol.iterator](),
        };
      }
      stmt.run(...bindings);
      return { toArray: () => [], one: () => { throw new Error("no rows"); } };
    },
  };
}
