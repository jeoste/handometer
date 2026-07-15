import { NextRequest, NextResponse } from "next/server";

// Classement Handometer — voir docs/LEADERBOARD.md à la racine du repo.
// Stockage : Upstash Redis via son API REST (aucune dépendance npm).

const REDIS_URL =
  process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL;
const REDIS_TOKEN =
  process.env.UPSTASH_REDIS_REST_TOKEN ?? process.env.KV_REST_API_TOKEN;

// Plafonds de vraisemblance par jour (anti-triche minimal, v1 déclarative).
const MAX_KEYSTROKES = 300_000;
const MAX_DISTANCE_CM = 500_000; // 5 km
const MAX_CLICKS = 100_000;

const TOP_SIZE = 50;
const DAILY_TTL = 3 * 86_400;
const WEEKLY_TTL = 35 * 86_400;

const UUID_RE = /^[0-9a-fA-F-]{36}$/;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

type Command = (string | number)[];

async function redisPipeline(commands: Command[]): Promise<unknown[]> {
  if (!REDIS_URL || !REDIS_TOKEN) {
    throw new Error("Redis credentials missing");
  }
  const res = await fetch(`${REDIS_URL}/pipeline`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${REDIS_TOKEN}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(commands),
    cache: "no-store",
  });
  if (!res.ok) throw new Error(`Redis error ${res.status}`);
  const results: { result: unknown; error?: string }[] = await res.json();
  const failed = results.find((r) => r.error);
  if (failed) throw new Error(`Redis command failed: ${failed.error}`);
  return results.map((r) => r.result);
}

/** Semaine ISO 8601 (« 2026-W29 ») pour une clé de jour « YYYY-MM-DD ». */
function isoWeekKey(dayKey: string): string {
  const d = new Date(`${dayKey}T00:00:00Z`);
  const day = (d.getUTCDay() + 6) % 7; // lundi = 0
  d.setUTCDate(d.getUTCDate() - day + 3); // jeudi de la semaine courante
  const week1 = new Date(Date.UTC(d.getUTCFullYear(), 0, 4));
  const week =
    1 +
    Math.round(
      ((d.getTime() - week1.getTime()) / 86_400_000 -
        3 +
        ((week1.getUTCDay() + 6) % 7)) /
        7,
    );
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, "0")}`;
}

/** dayKey plausible : date valide à ±2 jours de la date serveur. */
function isRecentDay(dayKey: string): boolean {
  const t = Date.parse(`${dayKey}T00:00:00Z`);
  if (Number.isNaN(t)) return false;
  return Math.abs(t - Date.now()) <= 3 * 86_400_000;
}

function sanitizeName(raw: string): string {
  // eslint-disable-next-line no-control-regex
  return raw.replace(/[\u0000-\u001F\u007F]/g, "").trim().slice(0, 24) || "Anonymous";
}

function clampCount(value: unknown, max: number): number | null {
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) return null;
  return Math.min(n, max);
}

// Même barème que l'XP locale (PlayerLevel.swift). Score calculé serveur.
function score(keystrokes: number, distanceCm: number, clicks: number): number {
  return Math.round(keystrokes + 0.1 * distanceCm + 2 * clicks);
}

export async function POST(req: NextRequest) {
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid JSON" }, { status: 400 });
  }

  const clientId = String(body.clientId ?? "");
  const dayKey = String(body.dayKey ?? "");
  const keystrokes = clampCount(body.keystrokes, MAX_KEYSTROKES);
  const distanceCm = clampCount(body.distanceCm, MAX_DISTANCE_CM);
  const clicks = clampCount(body.clicks, MAX_CLICKS);

  if (
    !UUID_RE.test(clientId) ||
    !DAY_RE.test(dayKey) ||
    !isRecentDay(dayKey) ||
    keystrokes === null ||
    distanceCm === null ||
    clicks === null
  ) {
    return NextResponse.json({ error: "invalid payload" }, { status: 400 });
  }

  const name = sanitizeName(String(body.name ?? ""));
  const dayScore = score(keystrokes, distanceCm, clicks);
  const weekKey = isoWeekKey(dayKey);
  const daysHash = `lb:days:${weekKey}:${clientId}`;

  try {
    // Écritures idempotentes + lecture des scores journaliers de la semaine.
    const results = await redisPipeline([
      ["HSET", "lb:names", clientId, name],
      ["ZADD", `lb:d:${dayKey}`, dayScore, clientId],
      ["EXPIRE", `lb:d:${dayKey}`, DAILY_TTL],
      ["HSET", daysHash, dayKey, dayScore],
      ["EXPIRE", daysHash, WEEKLY_TTL],
      ["HVALS", daysHash],
    ]);

    const weekScore = (results[5] as string[]).reduce(
      (sum, v) => sum + Number(v),
      0,
    );
    await redisPipeline([
      ["ZADD", `lb:w:${weekKey}`, weekScore, clientId],
      ["EXPIRE", `lb:w:${weekKey}`, WEEKLY_TTL],
    ]);

    return NextResponse.json({ ok: true, score: dayScore });
  } catch (err) {
    console.error("leaderboard submit failed:", err);
    return NextResponse.json({ error: "storage error" }, { status: 503 });
  }
}

export async function GET(req: NextRequest) {
  const params = req.nextUrl.searchParams;
  const period = params.get("period") === "weekly" ? "weekly" : "daily";
  const dayKey = params.get("dayKey") ?? "";
  const clientId = params.get("clientId") ?? "";

  if (!DAY_RE.test(dayKey) || !isRecentDay(dayKey)) {
    return NextResponse.json({ error: "invalid dayKey" }, { status: 400 });
  }

  const key =
    period === "weekly" ? `lb:w:${isoWeekKey(dayKey)}` : `lb:d:${dayKey}`;
  const wantsSelf = UUID_RE.test(clientId);

  try {
    const commands: Command[] = [
      ["ZRANGE", key, 0, TOP_SIZE - 1, "REV", "WITHSCORES"],
    ];
    if (wantsSelf) {
      commands.push(["ZREVRANK", key, clientId], ["ZSCORE", key, clientId]);
    }
    const results = await redisPipeline(commands);

    // ZRANGE WITHSCORES → [id1, score1, id2, score2, …]
    const flat = results[0] as string[];
    const ids: string[] = [];
    const scores: number[] = [];
    for (let i = 0; i < flat.length; i += 2) {
      ids.push(flat[i]);
      scores.push(Number(flat[i + 1]));
    }

    const names =
      ids.length > 0
        ? ((await redisPipeline([["HMGET", "lb:names", ...ids]]))[0] as (
            | string
            | null
          )[])
        : [];

    const entries = ids.map((id, i) => ({
      rank: i + 1,
      name: names[i] ?? "Anonymous",
      score: scores[i],
      isMe: wantsSelf && id === clientId,
    }));

    const rank = wantsSelf ? (results[1] as number | null) : null;
    const selfScore = wantsSelf ? (results[2] as string | null) : null;
    const me =
      rank !== null && selfScore !== null
        ? { rank: rank + 1, score: Math.round(Number(selfScore)) }
        : null;

    return NextResponse.json({ entries, me });
  } catch (err) {
    console.error("leaderboard fetch failed:", err);
    return NextResponse.json({ error: "storage error" }, { status: 503 });
  }
}
