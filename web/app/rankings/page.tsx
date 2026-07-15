"use client";

import Image from "next/image";
import Link from "next/link";
import { useCallback, useEffect, useState } from "react";

// Classement public — mêmes données que l'onglet Ranking de l'app macOS.

type Period = "daily" | "weekly" | "alltime";

type Entry = {
  rank: number;
  name: string;
  score: number;
  trophies: number;
  isMe: boolean;
};

const PERIODS: { id: Period; label: string }[] = [
  { id: "daily", label: "Today" },
  { id: "weekly", label: "This week" },
  { id: "alltime", label: "All-time" },
];

function localDayKey(): string {
  return new Date().toLocaleDateString("en-CA"); // YYYY-MM-DD local
}

function medal(rank: number): string {
  if (rank === 1) return "🥇";
  if (rank === 2) return "🥈";
  if (rank === 3) return "🥉";
  return `#${rank}`;
}

export default function Rankings() {
  const [period, setPeriod] = useState<Period>("daily");
  const [entries, setEntries] = useState<Entry[] | null>(null);
  const [error, setError] = useState(false);

  const load = useCallback(async (p: Period) => {
    setEntries(null);
    setError(false);
    try {
      const res = await fetch(
        `/api/leaderboard?period=${p}&dayKey=${localDayKey()}`,
        { cache: "no-store" },
      );
      if (!res.ok) throw new Error(String(res.status));
      const data = (await res.json()) as { entries: Entry[] };
      setEntries(data.entries);
    } catch {
      setError(true);
    }
  }, []);

  useEffect(() => {
    load(period);
  }, [period, load]);

  return (
    <div className="flex flex-1 flex-col">
      <header className="mx-auto flex w-full max-w-3xl items-center justify-between px-6 py-6">
        <Link href="/" className="flex items-center gap-3">
          <Image
            src="/icon.png"
            alt="Handometer"
            width={32}
            height={32}
            className="rounded-lg"
          />
          <span className="text-sm font-semibold tracking-tight">
            Handometer
          </span>
        </Link>
        <span className="text-sm font-medium text-zinc-900">Rankings</span>
      </header>

      <main className="mx-auto w-full max-w-3xl flex-1 px-6 py-10">
        <h1 className="text-2xl font-semibold tracking-tight text-zinc-900">
          Leaderboard
        </h1>
        <p className="mt-2 text-sm text-zinc-600">
          Scores from Handometer users who opted in — keystrokes, mouse
          distance and clicks, combined into XP.
        </p>

        <div className="mt-6 inline-flex rounded-lg border border-zinc-200 bg-zinc-50 p-1">
          {PERIODS.map((p) => (
            <button
              key={p.id}
              onClick={() => setPeriod(p.id)}
              className={`rounded-md px-4 py-1.5 text-sm transition-colors ${
                period === p.id
                  ? "bg-white font-medium text-zinc-900 shadow-sm"
                  : "text-zinc-500 hover:text-zinc-900"
              }`}
            >
              {p.label}
            </button>
          ))}
        </div>

        <div className="mt-6">
          {error ? (
            <p className="text-sm text-zinc-500">
              Couldn’t load the leaderboard. Try again later.
            </p>
          ) : entries === null ? (
            <p className="text-sm text-zinc-500">Loading…</p>
          ) : entries.length === 0 ? (
            <p className="text-sm text-zinc-500">
              No scores yet for this period — be the first!
            </p>
          ) : (
            <ol className="divide-y divide-zinc-100 rounded-xl border border-zinc-200 bg-white">
              {entries.map((entry) => (
                <li
                  key={entry.rank}
                  className="flex items-center gap-4 px-5 py-3"
                >
                  <span className="w-10 text-right font-medium tabular-nums text-zinc-900">
                    {medal(entry.rank)}
                  </span>
                  <span className="flex-1 truncate text-sm text-zinc-900">
                    {entry.name}
                    {entry.trophies > 0 && (
                      <span className="ml-2 text-xs text-zinc-400">
                        🏆 {entry.trophies}
                      </span>
                    )}
                  </span>
                  <span className="text-sm tabular-nums text-zinc-500">
                    {entry.score.toLocaleString()} XP
                  </span>
                </li>
              ))}
            </ol>
          )}
        </div>

        <p className="mt-6 text-xs text-zinc-400">
          Join from the app: Dashboard → Ranking → “Join the leaderboard”.
        </p>
      </main>

      <footer className="border-t border-zinc-100">
        <div className="mx-auto flex w-full max-w-3xl items-center justify-between px-6 py-8 text-sm text-zinc-500">
          <span>© {new Date().getFullYear()} Handometer</span>
          <Link href="/" className="hover:text-zinc-900">
            Home
          </Link>
        </div>
      </footer>
    </div>
  );
}
