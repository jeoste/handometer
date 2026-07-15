// Helpers partagés du classement (route API + cron d'attribution des trophées).

const REDIS_URL =
  process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL;
const REDIS_TOKEN =
  process.env.UPSTASH_REDIS_REST_TOKEN ?? process.env.KV_REST_API_TOKEN;

export type Command = (string | number)[];

export async function redisPipeline(commands: Command[]): Promise<unknown[]> {
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

// MARK: Clés de période

/** Semaine ISO 8601 (« 2026-W29 ») pour une clé de jour « YYYY-MM-DD ». */
export function isoWeekKey(dayKey: string): string {
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

export function monthKey(dayKey: string): string {
  return dayKey.slice(0, 7); // « 2026-07 »
}

export function quarterKey(dayKey: string): string {
  const month = Number(dayKey.slice(5, 7));
  return `${dayKey.slice(0, 4)}-Q${Math.ceil(month / 3)}`; // « 2026-Q3 »
}

export function yearKey(dayKey: string): string {
  return dayKey.slice(0, 4); // « 2026 »
}

// MARK: Périodes & trophées

export type TrophyPeriod = "day" | "week" | "month" | "quarter" | "year";

/** Clé Redis du zset de classement pour une période donnée. */
export function standingsKey(period: TrophyPeriod, dayKey: string): string {
  switch (period) {
    case "day":
      return `lb:d:${dayKey}`;
    case "week":
      return `lb:w:${isoWeekKey(dayKey)}`;
    case "month":
      return `lb:m:${monthKey(dayKey)}`;
    case "quarter":
      return `lb:q:${quarterKey(dayKey)}`;
    case "year":
      return `lb:y:${yearKey(dayKey)}`;
  }
}

/** Identifiant de la période close (pour marquage d'attribution + trophée). */
export function periodKey(period: TrophyPeriod, dayKey: string): string {
  switch (period) {
    case "day":
      return dayKey;
    case "week":
      return isoWeekKey(dayKey);
    case "month":
      return monthKey(dayKey);
    case "quarter":
      return quarterKey(dayKey);
    case "year":
      return yearKey(dayKey);
  }
}

/** XP bonus par rang (index 0 = 1er) pour chaque période. */
export const TROPHY_XP: Record<TrophyPeriod, number[]> = {
  day: [1_000, 600, 300],
  week: [5_000, 3_000, 1_500],
  month: [15_000, 9_000, 4_500],
  quarter: [40_000, 24_000, 12_000],
  year: [100_000, 60_000, 30_000],
};
