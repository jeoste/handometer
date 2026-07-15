import { NextRequest, NextResponse } from "next/server";
import {
  periodKey,
  redisPipeline,
  standingsKey,
  TROPHY_XP,
  TrophyPeriod,
} from "@/lib/leaderboard";

// Cron quotidien (12:00 UTC, voir vercel.json) : attribue les trophées du
// podium (top 3) pour chaque période close la veille. À 12:00 UTC, la
// journée « d'hier » est terminée dans tous les fuseaux horaires.
//
// Idempotent : un marqueur SETNX par période empêche toute double
// attribution, même si le cron rejoue.

/** Périodes closes pour une exécution donnée (UTC). */
function closedPeriods(now: Date): { period: TrophyPeriod; dayKey: string }[] {
  const yesterday = new Date(now.getTime() - 86_400_000);
  const dayKey = yesterday.toISOString().slice(0, 10);
  const periods: { period: TrophyPeriod; dayKey: string }[] = [
    { period: "day", dayKey },
  ];

  const isFirstOfMonth = now.getUTCDate() === 1;
  if (now.getUTCDay() === 1) periods.push({ period: "week", dayKey }); // lundi
  if (isFirstOfMonth) periods.push({ period: "month", dayKey });
  if (isFirstOfMonth && [0, 3, 6, 9].includes(now.getUTCMonth())) {
    periods.push({ period: "quarter", dayKey });
  }
  if (isFirstOfMonth && now.getUTCMonth() === 0) {
    periods.push({ period: "year", dayKey });
  }
  return periods;
}

type Awarded = {
  period: TrophyPeriod;
  periodKey: string;
  clientId: string;
  rank: number;
  score: number;
  xp: number;
};

async function award(
  period: TrophyPeriod,
  dayKey: string,
  dryRun: boolean,
): Promise<Awarded[] | "already-awarded"> {
  const pKey = periodKey(period, dayKey);
  const marker = `lb:awarded:${period}:${pKey}`;

  // Top 3 de la période close.
  const [top] = await redisPipeline([
    ["ZRANGE", standingsKey(period, dayKey), 0, 2, "REV", "WITHSCORES"],
  ]);
  const flat = top as string[];

  const winners: Awarded[] = [];
  for (let i = 0; i * 2 < flat.length; i++) {
    winners.push({
      period,
      periodKey: pKey,
      clientId: flat[i * 2],
      rank: i + 1,
      score: Math.round(Number(flat[i * 2 + 1])),
      xp: TROPHY_XP[period][i],
    });
  }
  if (dryRun || winners.length === 0) return winners;

  const [notYetAwarded] = await redisPipeline([["SETNX", marker, "1"]]);
  if (notYetAwarded !== 1) return "already-awarded";

  const commands = winners.flatMap((w): (string | number)[][] => [
    [
      "HSET",
      `lb:troph:${w.clientId}`,
      `${w.period}:${w.periodKey}`,
      JSON.stringify({ rank: w.rank, xp: w.xp, score: w.score }),
    ],
    ["HINCRBY", "lb:trophycount", w.clientId, 1],
    // L'XP du trophée compte aussi dans le classement all-time.
    ["ZINCRBY", "lb:a", w.xp, w.clientId],
  ]);
  await redisPipeline(commands);
  return winners;
}

export async function GET(req: NextRequest) {
  // Vercel Cron envoie `Authorization: Bearer ${CRON_SECRET}` si la variable
  // d'environnement existe sur le projet.
  const secret = process.env.CRON_SECRET;
  if (secret && req.headers.get("authorization") !== `Bearer ${secret}`) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  const dryRun = req.nextUrl.searchParams.get("dryRun") === "1";

  try {
    const results: Record<string, unknown> = {};
    for (const { period, dayKey } of closedPeriods(new Date())) {
      results[period] = await award(period, dayKey, dryRun);
    }
    return NextResponse.json({ dryRun, results });
  } catch (err) {
    console.error("trophy award failed:", err);
    return NextResponse.json({ error: "storage error" }, { status: 503 });
  }
}
