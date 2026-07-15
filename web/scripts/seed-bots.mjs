#!/usr/bin/env node
// Peuple le classement avec des bots de test (nom préfixé « BOT »).
// UUID fixes → ré-exécution idempotente (met à jour le jour courant, ne
// duplique jamais). Usage :
//   node scripts/seed-bots.mjs [baseURL]
// baseURL par défaut : https://handometer.vercel.app

const BASE_URL = process.argv[2] ?? "https://handometer.vercel.app";

// Profils : [uuid fixe, nom, frappes min-max, distance cm min-max, clics min-max]
const BOTS = [
  ["11111111-0000-4000-8000-000000000001", "BOT Clanker",   [25_000, 60_000], [150_000, 400_000], [4_000, 9_000]],
  ["11111111-0000-4000-8000-000000000002", "BOT Turbo",     [15_000, 40_000], [100_000, 300_000], [2_500, 6_000]],
  ["11111111-0000-4000-8000-000000000003", "BOT Marathon",  [8_000, 20_000],  [200_000, 450_000], [1_500, 4_000]],
  ["11111111-0000-4000-8000-000000000004", "BOT Scribe",    [30_000, 70_000], [20_000, 80_000],   [800, 2_500]],
  ["11111111-0000-4000-8000-000000000005", "BOT Clicky",    [3_000, 10_000],  [60_000, 150_000],  [8_000, 20_000]],
  ["11111111-0000-4000-8000-000000000006", "BOT Casual",    [1_000, 5_000],   [10_000, 50_000],   [300, 1_200]],
  ["11111111-0000-4000-8000-000000000007", "BOT Nocturne",  [5_000, 15_000],  [40_000, 120_000],  [1_000, 3_000]],
  ["11111111-0000-4000-8000-000000000008", "BOT Zen",       [500, 2_000],     [5_000, 25_000],    [100, 500]],
];

const rand = ([min, max]) => Math.floor(min + Math.random() * (max - min));
const dayKey = new Date().toLocaleDateString("en-CA"); // YYYY-MM-DD local

for (const [clientId, name, keys, dist, clicks] of BOTS) {
  const payload = {
    clientId,
    name,
    dayKey,
    keystrokes: rand(keys),
    distanceCm: rand(dist),
    clicks: rand(clicks),
  };
  const res = await fetch(`${BASE_URL}/api/leaderboard`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  const body = await res.json();
  console.log(
    `${name.padEnd(14)} ${res.status} score=${body.score ?? "?"} display=${body.displayName ?? "?"}`,
  );
}
