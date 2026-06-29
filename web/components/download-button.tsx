export function DownloadButton({ className = "" }: { className?: string }) {
  return (
    <a
      href="/api/download"
      className={`inline-flex items-center justify-center rounded-full bg-zinc-900 px-6 py-3 text-sm font-medium text-white transition-colors hover:bg-zinc-700 ${className}`}
    >
      Download for macOS
    </a>
  );
}
