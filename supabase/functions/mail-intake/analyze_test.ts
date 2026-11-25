// Run with: MAIL_INTAKE_TEST=1 deno test --allow-env supabase/functions/mail-intake
import { assertEquals, assertRejects, assertStringIncludes } from "jsr:@std/assert@1";
import {
  AnalysisUnavailable,
  type AnalyzeInput,
  buildUserMessage,
  checkSuggestion,
  createAnthropicAnalyzer,
  parseModelAnswer,
  type Suggestion,
  validateSuggestion,
} from "./analyze.ts";

const input: AnalyzeInput = {
  sender: "Teacher <teacher@school.example>",
  subject: "Costume day",
  receivedAt: "2026-12-01T08:00:00.000Z",
  body: "Please bring a costume on Friday and 5 pounds for the charity.",
  context: "Child Test goes to Example School, class Owls.",
  today: "2026-12-01",
};

const good: Suggestion = {
  kind: "task",
  title: "Costume for Child Test",
  date: "2026-12-04",
  time: null,
  amount: 5,
  currency: "GBP",
  summary: "Kostüm und 5 GBP mitbringen.",
};

Deno.test("a valid suggestion is accepted", () => {
  assertEquals(validateSuggestion(good), good);
});

Deno.test("tasks have no time and amounts without currency drop the currency", () => {
  const result = validateSuggestion({ ...good, time: "09:00", currency: null });
  assertEquals(result?.time, null);
  assertEquals(result?.currency, null);
  assertEquals(validateSuggestion({ ...good, amount: null })?.currency, null);
});

Deno.test("suggestions of kind none carry no date or money", () => {
  const result = validateSuggestion({ ...good, kind: "none" });
  assertEquals([result?.date, result?.time, result?.amount, result?.currency], [null, null, null, null]);
});

Deno.test("unusable suggestions are rejected", () => {
  assertEquals(validateSuggestion(null), null);
  assertEquals(validateSuggestion([]), null);
  assertEquals(validateSuggestion({ ...good, kind: "delete" }), null);
  assertEquals(validateSuggestion({ ...good, title: "  " }), null);
  assertEquals(validateSuggestion({ ...good, summary: undefined }), null);
  assertEquals(validateSuggestion({ ...good, date: "next friday" }), null);
  assertEquals(validateSuggestion({ ...good, date: "2026-13-45" }), null);
  assertEquals(validateSuggestion({ ...good, time: "25:00" }), null);
  assertEquals(validateSuggestion({ ...good, amount: -3 }), null);
  assertEquals(validateSuggestion({ ...good, amount: "five" }), null);
  assertEquals(validateSuggestion({ ...good, currency: "pounds" }), null);
});

Deno.test("harmless deviations are tolerated", () => {
  const result = validateSuggestion({ ...good, amount: "5,50", currency: "gbp", date: "", time: "" });
  assertEquals(result?.amount, 5.5);
  assertEquals(result?.currency, "GBP");
  assertEquals(result?.date, null);
});

Deno.test("the reason for a rejection names the field but not its content", () => {
  assertEquals(checkSuggestion({ ...good, date: "secret-date" }), { ok: false, reason: "date" });
  assertEquals(checkSuggestion({ ...good, kind: "other" }), { ok: false, reason: "kind" });
  assertEquals(checkSuggestion("nope"), { ok: false, reason: "not an object" });
});

Deno.test("long texts are shortened", () => {
  const result = validateSuggestion({ ...good, title: "t".repeat(500), summary: "s".repeat(2000) });
  assertEquals(result?.title.length, 200);
  assertEquals(result?.summary.length, 600);
});

Deno.test("the JSON is found inside fences or surrounding text", () => {
  assertEquals(parseModelAnswer('```json\n{"a":1}\n```'), { a: 1 });
  assertEquals(parseModelAnswer('Sure! {"a":1} Hope that helps.'), { a: 1 });
  assertEquals(parseModelAnswer("no json here"), null);
  assertEquals(parseModelAnswer("{broken"), null);
});

Deno.test("the prompt marks the mail as data and includes context and date", () => {
  const message = buildUserMessage(input);
  assertStringIncludes(message, "Today: 2026-12-01");
  assertStringIncludes(message, "Child Test goes to Example School");
  assertStringIncludes(message, "<mail>");
  assertStringIncludes(message, "Please bring a costume");
});

function fakeApi(answer: string, status = 200) {
  const calls: { url: string; init: RequestInit }[] = [];
  const impl = ((url: string | URL | Request, init?: RequestInit) => {
    calls.push({ url: String(url), init: init ?? {} });
    return Promise.resolve(
      new Response(JSON.stringify({ content: [{ type: "text", text: answer }] }), { status }),
    );
  }) as typeof fetch;
  return { impl, calls };
}

Deno.test("the analyzer calls the API with the key and returns the validated suggestion", async () => {
  const { impl, calls } = fakeApi(JSON.stringify(good));
  const result = await createAnthropicAnalyzer("test-key", "test-model", impl)(input);
  assertEquals(result, good);
  assertEquals(calls[0].url, "https://api.anthropic.com/v1/messages");
  const headers = calls[0].init.headers as Record<string, string>;
  assertEquals(headers["x-api-key"], "test-key");
  const sent = JSON.parse(String(calls[0].init.body));
  assertEquals(sent.model, "test-model");
  assertEquals(sent.tools, undefined);
});

Deno.test("an answer that cannot be read becomes a suggestion of kind none", async () => {
  const { impl } = fakeApi("I could not decide.");
  const result = await createAnthropicAnalyzer("test-key", "test-model", impl)(input);
  assertEquals(result.kind, "none");
  assertEquals(result.title, "Costume day");
});

Deno.test("API errors and a missing key throw so that the mail is retried", async () => {
  const { impl } = fakeApi("{}", 529);
  await assertRejects(() => createAnthropicAnalyzer("test-key", "m", impl)(input), AnalysisUnavailable);
  await assertRejects(() => createAnthropicAnalyzer(undefined, "m", impl)(input), AnalysisUnavailable);
});

Deno.test("an answer without JSON is asked for a second time", async () => {
  let calls = 0;
  const impl = (() => {
    calls++;
    const text = calls === 1 ? "I cannot help with that." : JSON.stringify(good);
    return Promise.resolve(new Response(JSON.stringify({ content: [{ type: "text", text }] })));
  }) as typeof fetch;
  const result = await createAnthropicAnalyzer("test-key", "test-model", impl)(input);
  assertEquals(calls, 2);
  assertEquals(result, good);
});

Deno.test("two answers without JSON give a suggestion of kind none", async () => {
  let calls = 0;
  const impl = (() => {
    calls++;
    return Promise.resolve(new Response(JSON.stringify({ content: [], stop_reason: "refusal" })));
  }) as typeof fetch;
  const result = await createAnthropicAnalyzer("test-key", "test-model", impl)(input);
  assertEquals(calls, 2);
  assertEquals(result.kind, "none");
});
