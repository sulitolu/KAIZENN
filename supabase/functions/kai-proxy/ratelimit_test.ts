import { assertEquals } from "jsr:@std/assert@1";
import { CHAT_LIMIT, checkAndIncrement, type Db, VISION_LIMIT } from "./ratelimit.ts";

function memDb(): Db & { store: Map<string, { chat: number; vision: number }> } {
  const m = new Map<string, { chat: number; vision: number }>();
  const k = (id: string, d: string) => `${id}:${d}`;
  return {
    store: m,
    getCounts(id: string, d: string) {
      return Promise.resolve(m.get(k(id, d)) ?? { chat: 0, vision: 0 });
    },
    increment(id: string, d: string, kind: "chat" | "vision") {
      const c = m.get(k(id, d)) ?? { chat: 0, vision: 0 };
      c[kind]++;
      m.set(k(id, d), c);
      return Promise.resolve();
    },
  };
}

Deno.test("allows under the chat cap and increments", async () => {
  const db = memDb();
  const r = await checkAndIncrement(db, "dev1", "chat", "2026-06-20");
  assertEquals(r.allowed, true);
  assertEquals((await db.getCounts("dev1", "2026-06-20")).chat, 1);
});

Deno.test("blocks at the chat cap and does not increment further", async () => {
  const db = memDb();
  db.store.set("dev1:2026-06-20", { chat: CHAT_LIMIT, vision: 0 });
  const r = await checkAndIncrement(db, "dev1", "chat", "2026-06-20");
  assertEquals(r.allowed, false);
  assertEquals((await db.getCounts("dev1", "2026-06-20")).chat, CHAT_LIMIT);
});

Deno.test("vision cap is independent of chat", async () => {
  const db = memDb();
  db.store.set("dev1:2026-06-20", { chat: CHAT_LIMIT, vision: VISION_LIMIT - 1 });
  assertEquals((await checkAndIncrement(db, "dev1", "vision", "2026-06-20")).allowed, true);
  assertEquals((await checkAndIncrement(db, "dev1", "vision", "2026-06-20")).allowed, false);
});

Deno.test("limits reset on a new day key", async () => {
  const db = memDb();
  db.store.set("dev1:2026-06-20", { chat: CHAT_LIMIT, vision: VISION_LIMIT });
  const r = await checkAndIncrement(db, "dev1", "chat", "2026-06-21");
  assertEquals(r.allowed, true);
});

Deno.test("limits are per-device", async () => {
  const db = memDb();
  db.store.set("dev1:2026-06-20", { chat: CHAT_LIMIT, vision: 0 });
  const r = await checkAndIncrement(db, "dev2", "chat", "2026-06-20");
  assertEquals(r.allowed, true);
});
