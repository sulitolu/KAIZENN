import { assertEquals } from "jsr:@std/assert@1";
import { buildChatBody, buildVisionBody, callAnthropic } from "./anthropic.ts";

Deno.test("buildChatBody pins model, max_tokens, and passes system + messages", () => {
  const b = buildChatBody([{ role: "user", content: "hi" }], "sys") as Record<string, unknown>;
  assertEquals(b.model, "claude-sonnet-4-6");
  assertEquals(b.max_tokens, 1024);
  assertEquals(b.system, "sys");
  assertEquals(b.messages, [{ role: "user", content: "hi" }]);
});

Deno.test("buildVisionBody embeds a base64 image block before the text block", () => {
  const b = buildVisionBody("AAAA", "sys") as {
    model: string;
    messages: { content: { type: string; source?: { data: string } }[] }[];
  };
  assertEquals(b.model, "claude-sonnet-4-6");
  const content = b.messages[0].content;
  assertEquals(content[0].type, "image");
  assertEquals(content[0].source?.data, "AAAA");
  assertEquals(content[1].type, "text");
});

Deno.test("callAnthropic returns assistant text on 200", async () => {
  const fake: typeof fetch = () =>
    Promise.resolve(
      new Response(JSON.stringify({ content: [{ text: "hello" }] }), { status: 200 }),
    );
  const r = await callAnthropic("k", buildChatBody([{ role: "user", content: "x" }], "s"), fake);
  assertEquals(r.status, 200);
  assertEquals(r.text, "hello");
});

Deno.test("callAnthropic surfaces non-2xx status and raw error body", async () => {
  const fake: typeof fetch = () =>
    Promise.resolve(new Response("over quota", { status: 400 }));
  const r = await callAnthropic("k", buildChatBody([{ role: "user", content: "x" }], "s"), fake);
  assertEquals(r.status, 400);
  assertEquals(r.text, "over quota");
});

Deno.test("callAnthropic sends the pinned headers and the given key", async () => {
  let seen: Headers | undefined;
  const fake: typeof fetch = (_url, init) => {
    seen = new Headers(init?.headers);
    return Promise.resolve(
      new Response(JSON.stringify({ content: [{ text: "ok" }] }), { status: 200 }),
    );
  };
  await callAnthropic("secret-key", buildChatBody([{ role: "user", content: "x" }], "s"), fake);
  assertEquals(seen?.get("x-api-key"), "secret-key");
  assertEquals(seen?.get("anthropic-version"), "2023-06-01");
});
