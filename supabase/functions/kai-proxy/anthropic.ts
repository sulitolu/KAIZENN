// Server-pinned Anthropic request params. The client never chooses the model or
// token budget — this is the cost-control half of the locked-down proxy contract.
const MODEL = "claude-sonnet-4-6";
const MAX_TOKENS = 1024;
const VERSION = "2023-06-01";
const URL = "https://api.anthropic.com/v1/messages";

export function buildChatBody(
  messages: { role: string; content: string }[],
  systemPrompt: string,
) {
  return { model: MODEL, max_tokens: MAX_TOKENS, system: systemPrompt, messages };
}

export function buildVisionBody(imageBase64: string, systemPrompt: string) {
  return {
    model: MODEL,
    max_tokens: MAX_TOKENS,
    system: systemPrompt,
    messages: [{
      role: "user",
      content: [
        { type: "image", source: { type: "base64", media_type: "image/jpeg", data: imageBase64 } },
        { type: "text", text: "Analyse this image and respond with structured JSON only." },
      ],
    }],
  };
}

/** Forward a pre-built body to Anthropic. Returns the assistant text on 2xx, or the
 *  raw error body + status otherwise. `fetchImpl` is injectable for testing. */
export async function callAnthropic(
  apiKey: string,
  body: object,
  fetchImpl: typeof fetch = fetch,
): Promise<{ status: number; text: string }> {
  const res = await fetchImpl(URL, {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": VERSION,
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (res.status < 200 || res.status >= 300) {
    return { status: res.status, text: await res.text() };
  }
  const json = await res.json();
  return { status: 200, text: json.content?.[0]?.text ?? "" };
}
