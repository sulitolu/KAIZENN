// Per-device daily request caps. Starting values, tunable here without a schema
// change (the usage_counters table is keyed by (key_id, day)).
export const CHAT_LIMIT = 50;
export const VISION_LIMIT = 20;

export interface Db {
  getCounts(keyId: string, day: string): Promise<{ chat: number; vision: number }>;
  increment(keyId: string, day: string, kind: "chat" | "vision"): Promise<void>;
}

/**
 * Check the per-device daily cap for `kind` on `today` (an ISO date string).
 * Increments and allows when under the cap; denies without incrementing when at/over.
 */
export async function checkAndIncrement(
  db: Db,
  keyId: string,
  kind: "chat" | "vision",
  today: string,
): Promise<{ allowed: boolean }> {
  const counts = await db.getCounts(keyId, today);
  const cap = kind === "chat" ? CHAT_LIMIT : VISION_LIMIT;
  if (counts[kind] >= cap) return { allowed: false };
  await db.increment(keyId, today, kind);
  return { allowed: true };
}
