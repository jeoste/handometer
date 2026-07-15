import { NextRequest, NextResponse } from "next/server";
import {
  Command,
  isoWeekKey,
  monthKey,
  quarterKey,
  redisPipeline,
  yearKey,
} from "@/lib/leaderboard";

// Classement Handometer — voir docs/LEADERBOARD.md à la racine du repo.
// Stockage : Upstash Redis via son API REST (aucune dépendance npm).

// Plafonds de vraisemblance par jour (anti-triche minimal, v1 déclarative).
const MAX_KEYSTROKES = 300_000;
const MAX_DISTANCE_CM = 500_000; // 5 km
const MAX_CLICKS = 100_000;

// XP lifetime déclarée par le client (plafond de vraisemblance large).
const MAX_LIFETIME_XP = 100_000_000;

const TOP_SIZE = 50;
const DAILY_TTL = 3 * 86_400;
const WEEKLY_TTL = 35 * 86_400;
const MONTHLY_TTL = 65 * 86_400;
const QUARTERLY_TTL = 130 * 86_400;
const YEARLY_TTL = 400 * 86_400;

const UUID_RE = /^[0-9a-fA-F-]{36}$/;
const DAY_RE = /^\d{4}-\d{2}-\d{2}$/;

/** dayKey plausible : date valide à ±2 jours de la date serveur. */
function isRecentDay(dayKey: string): boolean {
  const t = Date.parse(`${dayKey}T00:00:00Z`);
  if (Number.isNaN(t)) return false;
  return Math.abs(t - Date.now()) <= 3 * 86_400_000;
}

function sanitizeName(raw: string): string {
  // eslint-disable-next-line no-control-regex
  return raw.replace(/[\u0000-\u001F\u007F#]/g, "").trim().slice(0, 24) || "Anonymous";
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

/** Discriminateur style Discord, déterministe depuis le clientId (stable,
 *  aucun état à stocker) : 4 chiffres 1000-9999. */
function discriminator(clientId: string): string {
  const n = parseInt(clientId.replace(/-/g, "").slice(0, 8), 16);
  return String((n % 9000) + 1000);
}

/**
 * Unicité des pseudos, premier arrivé premier servi :
 * - le premier client à revendiquer « jeoste » l'affiche tel quel ;
 * - tout autre client choisissant « jeoste » affiche « jeoste#4821 » ;
 * - changer de pseudo libère l'ancien nom.
 * Clés : `lb:name_owner` (base minuscule → clientId propriétaire) et
 * `lb:name_base` (clientId → base revendiquée, pour la libération).
 */
async function resolveDisplayName(
  clientId: string,
  base: string,
): Promise<string> {
  const lower = base.toLowerCase();
  const results = await redisPipeline([
    ["HGET", "lb:name_base", clientId],
    ["HSETNX", "lb:name_owner", lower, clientId],
    ["HGET", "lb:name_owner", lower],
    ["HSET", "lb:name_base", clientId, lower],
  ]);
  const previousBase = results[0] as string | null;
  const owner = results[2] as string | null;

  // Renommage : libère l'ancienne base si ce client la possédait.
  if (previousBase && previousBase !== lower) {
    const [previousOwner] = await redisPipeline([
      ["HGET", "lb:name_owner", previousBase],
    ]);
    if (previousOwner === clientId) {
      await redisPipeline([["HDEL", "lb:name_owner", previousBase]]);
    }
  }

  return owner === clientId ? base : `${base}#${discriminator(clientId)}`;
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

  // Optionnelle : absente chez les anciens clients (repli sur delta).
  const lifetimeXp =
    body.lifetimeXp === undefined
      ? null
      : clampCount(body.lifetimeXp, MAX_LIFETIME_XP);

  const dayScore = score(keystrokes, distanceCm, clicks);
  const weekKey = isoWeekKey(dayKey);
  const daysHash = `lb:days:${weekKey}:${clientId}`;

  try {
    const name = await resolveDisplayName(
      clientId,
      sanitizeName(String(body.name ?? "")),
    );
    // Écritures idempotentes + lecture des scores journaliers de la semaine.
    // HGET en tête : valeur précédente du jour, pour la mise à jour
    // incrémentale des classements longue durée (delta = nouveau − précédent).
    const results = await redisPipeline([
      ["HGET", daysHash, dayKey],
      ["HSET", "lb:names", clientId, name],
      ["ZADD", `lb:d:${dayKey}`, dayScore, clientId],
      ["EXPIRE", `lb:d:${dayKey}`, DAILY_TTL],
      ["HSET", daysHash, dayKey, dayScore],
      ["EXPIRE", daysHash, WEEKLY_TTL],
      ["HVALS", daysHash],
    ]);

    const previousDayScore = Number((results[0] as string | null) ?? 0);
    const delta = dayScore - previousDayScore;
    const weekScore = (results[6] as string[]).reduce(
      (sum, v) => sum + Number(v),
      0,
    );
    await redisPipeline([
      ["ZADD", `lb:w:${weekKey}`, weekScore, clientId],
      ["EXPIRE", `lb:w:${weekKey}`, WEEKLY_TTL],
      // Cumuls incrémentaux : mois, trimestre, année, all-time (jamais expiré).
      ["ZINCRBY", `lb:m:${monthKey(dayKey)}`, delta, clientId],
      ["EXPIRE", `lb:m:${monthKey(dayKey)}`, MONTHLY_TTL],
      ["ZINCRBY", `lb:q:${quarterKey(dayKey)}`, delta, clientId],
      ["EXPIRE", `lb:q:${quarterKey(dayKey)}`, QUARTERLY_TTL],
      ["ZINCRBY", `lb:y:${yearKey(dayKey)}`, delta, clientId],
      ["EXPIRE", `lb:y:${yearKey(dayKey)}`, YEARLY_TTL],
      // All-time = XP lifetime totale de l'app (historique complet + bonus),
      // envoyée par le client et écrite telle quelle — cohérente avec le
      // niveau affiché localement. Repli sur le cumul par delta pour les
      // anciens clients qui ne l'envoient pas.
      lifetimeXp !== null
        ? ["ZADD", "lb:a", lifetimeXp, clientId]
        : ["ZINCRBY", "lb:a", delta, clientId],
    ]);

    return NextResponse.json({ ok: true, score: dayScore, displayName: name });
  } catch (err) {
    console.error("leaderboard submit failed:", err);
    return NextResponse.json({ error: "storage error" }, { status: 503 });
  }
}

const GET_KEYS: Record<string, (dayKey: string) => string> = {
  daily: (d) => `lb:d:${d}`,
  weekly: (d) => `lb:w:${isoWeekKey(d)}`,
  monthly: (d) => `lb:m:${monthKey(d)}`,
  quarterly: (d) => `lb:q:${quarterKey(d)}`,
  yearly: (d) => `lb:y:${yearKey(d)}`,
  alltime: () => "lb:a",
};

export async function GET(req: NextRequest) {
  const params = req.nextUrl.searchParams;
  const rawPeriod = params.get("period") ?? "daily";
  const period = rawPeriod in GET_KEYS ? rawPeriod : "daily";
  const dayKey = params.get("dayKey") ?? "";
  const clientId = params.get("clientId") ?? "";

  if (period !== "alltime" && (!DAY_RE.test(dayKey) || !isRecentDay(dayKey))) {
    return NextResponse.json({ error: "invalid dayKey" }, { status: 400 });
  }

  const key = GET_KEYS[period](dayKey);
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

    // Pseudos + nombre de trophées des entrées du top.
    let names: (string | null)[] = [];
    let trophyCounts: (string | null)[] = [];
    if (ids.length > 0) {
      const meta = await redisPipeline([
        ["HMGET", "lb:names", ...ids],
        ["HMGET", "lb:trophycount", ...ids],
      ]);
      names = meta[0] as (string | null)[];
      trophyCounts = meta[1] as (string | null)[];
    }

    const entries = ids.map((id, i) => ({
      rank: i + 1,
      name: names[i] ?? "Anonymous",
      score: Math.round(scores[i]),
      trophies: Number(trophyCounts[i] ?? 0),
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
