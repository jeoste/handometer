import { NextRequest, NextResponse } from "next/server";
import { redisPipeline } from "@/lib/leaderboard";

// Collection de trophées d'un utilisateur (podiums de fin de période),
// consommée par l'app macOS pour l'affichage et le bonus d'XP.

const UUID_RE = /^[0-9a-fA-F-]{36}$/;

export async function GET(req: NextRequest) {
  const clientId = req.nextUrl.searchParams.get("clientId") ?? "";
  if (!UUID_RE.test(clientId)) {
    return NextResponse.json({ error: "invalid clientId" }, { status: 400 });
  }

  try {
    const [hash] = await redisPipeline([["HGETALL", `lb:troph:${clientId}`]]);
    // HGETALL → [field1, value1, field2, value2, …]
    const flat = (hash as string[]) ?? [];

    const trophies: {
      id: string;
      period: string;
      periodKey: string;
      rank: number;
      xp: number;
      score: number;
    }[] = [];
    let totalXp = 0;

    for (let i = 0; i < flat.length; i += 2) {
      const id = flat[i]; // « day:2026-07-15 », « week:2026-W29 », …
      const sep = id.indexOf(":");
      let payload: { rank?: number; xp?: number; score?: number } = {};
      try {
        payload = JSON.parse(flat[i + 1]);
      } catch {
        continue;
      }
      const xp = Number(payload.xp ?? 0);
      totalXp += xp;
      trophies.push({
        id,
        period: id.slice(0, sep),
        periodKey: id.slice(sep + 1),
        rank: Number(payload.rank ?? 0),
        xp,
        score: Number(payload.score ?? 0),
      });
    }

    // Plus récents d'abord (les periodKeys sont triables lexicalement par type).
    trophies.sort((a, b) => b.periodKey.localeCompare(a.periodKey));

    return NextResponse.json({ trophies, totalXp });
  } catch (err) {
    console.error("trophies fetch failed:", err);
    return NextResponse.json({ error: "storage error" }, { status: 503 });
  }
}
