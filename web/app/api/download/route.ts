export async function GET() {
  const res = await fetch(
    "https://api.github.com/repos/jeoste/handometer/releases/latest",
    { next: { revalidate: 300 } },
  );

  if (!res.ok) {
    return new Response("Release not found", { status: 502 });
  }

  const release = await res.json();
  const asset = release.assets?.find((a: { name: string }) =>
    a.name.endsWith(".zip"),
  );

  if (!asset?.browser_download_url) {
    return new Response("No zip asset", { status: 404 });
  }

  return Response.redirect(asset.browser_download_url, 302);
}
