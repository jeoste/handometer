import Image from "next/image";
import { DownloadButton } from "@/components/download-button";

const features = [
  {
    title: "Mouse distance",
    description:
      "Track how far your cursor travels each day — in real centimeters, multi-monitor aware.",
    icon: "📏",
  },
  {
    title: "Speed",
    description:
      "See your average and peak mouse speed in km/h.",
    icon: "🏎️",
  },
  {
    title: "Clicks",
    description:
      "Counts left, right, and middle clicks separately.",
    icon: "🖱️",
  },
  {
    title: "Key frequency",
    description:
      'Type "hello" → h×1, e×1, l×2, o×1. Per-character counts only.',
    icon: "⌨️",
  },
  {
    title: "History charts",
    description:
      "Today's dashboard plus daily history to spot trends over time.",
    icon: "📊",
  },
  {
    title: "Export",
    description: "Export your stats as CSV or JSON anytime.",
    icon: "💾",
  },
];

export default function Home() {
  return (
    <div className="flex flex-1 flex-col">
      <header className="mx-auto flex w-full max-w-3xl items-center justify-between px-6 py-6">
        <div className="flex items-center gap-3">
          <Image
            src="/icon.png"
            alt="Handometer"
            width={32}
            height={32}
            className="rounded-lg"
          />
          <span className="text-sm font-semibold tracking-tight">Handometer</span>
        </div>
        <DownloadButton className="!px-4 !py-2 text-xs" />
      </header>

      <main className="flex flex-1 flex-col">
        <section className="mx-auto flex w-full max-w-3xl flex-col items-center px-6 py-16 text-center sm:py-24">
          <Image
            src="/icon.png"
            alt="Handometer app icon"
            width={96}
            height={96}
            className="mb-8 rounded-2xl shadow-sm"
            priority
          />
          <h1 className="max-w-lg text-4xl font-semibold tracking-tight text-zinc-900 sm:text-5xl">
            A pedometer for your hands
          </h1>
          <p className="mt-4 max-w-md text-lg leading-relaxed text-zinc-600">
            Handometer tracks the distance your cursor travels and how often you
            press each key — per day, right from your menu bar.
          </p>
          <div className="mt-8">
            <DownloadButton />
          </div>
          <p className="mt-3 text-sm text-zinc-500">
            macOS 13+ · Free · MIT license
          </p>
        </section>

        <section className="border-t border-zinc-100 bg-zinc-50/50">
          <div className="mx-auto w-full max-w-3xl px-6 py-16">
            <h2 className="text-center text-sm font-medium uppercase tracking-wider text-zinc-500">
              Features
            </h2>
            <div className="mt-10 grid gap-6 sm:grid-cols-2">
              {features.map((feature) => (
                <div
                  key={feature.title}
                  className="rounded-xl border border-zinc-200 bg-white p-5"
                >
                  <span className="text-xl" aria-hidden="true">
                    {feature.icon}
                  </span>
                  <h3 className="mt-2 font-medium text-zinc-900">
                    {feature.title}
                  </h3>
                  <p className="mt-1 text-sm leading-relaxed text-zinc-600">
                    {feature.description}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="mx-auto w-full max-w-3xl px-6 py-16">
          <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-6 text-center">
            <h2 className="font-medium text-emerald-900">100% local & private</h2>
            <p className="mt-2 text-sm leading-relaxed text-emerald-800">
              Everything stays on your Mac. Only per-character counters are stored
              — never the words you type or the order of keystrokes.
            </p>
          </div>
        </section>

        <section className="border-t border-zinc-100">
          <div className="mx-auto w-full max-w-3xl px-6 py-16">
            <h2 className="text-sm font-medium uppercase tracking-wider text-zinc-500">
              First launch
            </h2>
            <ol className="mt-6 space-y-3 text-sm leading-relaxed text-zinc-600">
              <li>
                <span className="font-medium text-zinc-900">1.</span> Unzip and
                drag <code className="rounded bg-zinc-100 px-1.5 py-0.5 text-xs">Handometer.app</code> into{" "}
                <code className="rounded bg-zinc-100 px-1.5 py-0.5 text-xs">/Applications</code>.
              </li>
              <li>
                <span className="font-medium text-zinc-900">2.</span>{" "}
                <strong>Right-click the app → Open</strong> to bypass the
                unsigned-app warning (only needed once).
              </li>
              <li>
                <span className="font-medium text-zinc-900">3.</span> Grant{" "}
                <strong>Accessibility</strong> permission in System Settings so
                keystrokes and clicks can be counted.
              </li>
            </ol>
            <p className="mt-4 text-sm text-zinc-500">
              The icon appears in your menu bar. Click it to see stats or open
              the dashboard.
            </p>
          </div>
        </section>
      </main>

      <footer className="border-t border-zinc-100">
        <div className="mx-auto flex w-full max-w-3xl flex-col items-center gap-2 px-6 py-8 text-sm text-zinc-500 sm:flex-row sm:justify-between">
          <span>© {new Date().getFullYear()} Handometer</span>
          <div className="flex gap-4">
            <a
              href="https://github.com/jeoste/handometer"
              className="hover:text-zinc-900"
              target="_blank"
              rel="noopener noreferrer"
            >
              GitHub
            </a>
            <a
              href="https://github.com/jeoste/handometer/blob/main/LICENSE"
              className="hover:text-zinc-900"
              target="_blank"
              rel="noopener noreferrer"
            >
              MIT License
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
