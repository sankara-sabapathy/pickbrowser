"use strict";
// Public release metadata only. No cookies, analytics, or persisted identifiers.
const repository = "sankara-sabapathy/pickbrowser";
fetch(`https://api.github.com/repos/${repository}/releases/latest`, {
  headers: { Accept: "application/vnd.github+json" },
  credentials: "omit",
  signal: AbortSignal.timeout(6000)
}).then(response => {
  if (!response.ok) throw new Error("Release unavailable");
  return response.json();
}).then(release => {
  if (release.draft || release.prerelease || !/^v\d+\.\d+\.\d+$/.test(release.tag_name)) return;
  const asset = release.assets?.find(asset => asset.name === "PickBrowser-macOS.zip");
  const expected = `https://github.com/${repository}/releases/download/${release.tag_name}/PickBrowser-macOS.zip`;
  if (!asset || asset.browser_download_url !== expected) return;
  document.getElementById("download").href = expected;
  document.getElementById("release-status").textContent = `${release.tag_name} · ${Math.ceil(asset.size / 1048576)} MB universal download`;
  if (release.body?.includes("This build is Developer ID signed and notarized by Apple.")) {
    document.getElementById("distribution-note").textContent = "Developer ID signed and notarized by Apple. Move PickBrowser to Applications before opening it.";
  }
}).catch(() => {
  // Keep the ordinary GitHub link usable when its API is unavailable or rate limited.
});
