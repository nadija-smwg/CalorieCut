import { test, expect } from '@playwright/test';
import { onboard, logEgg } from './helpers.js';
import { staticSite } from './static-site.js';
async function controlled(page) {
  await page.evaluate(async () => { await navigator.serviceWorker.ready; if (!navigator.serviceWorker.controller) await new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, { once: true })); });
}
test('subdirectory hosting has valid manifest, icons and an offline app shell', async ({ page, context }) => {
  const site = await staticSite();
  try {
    await onboard(page, site.url); await logEgg(page); await controlled(page);
    const manifest = await page.evaluate(async () => { const url = new URL(document.querySelector('link[rel=manifest]').href), m = await (await fetch(url)).json(); return { scope: new URL(m.scope, url).pathname, display: m.display, icons: await Promise.all(m.icons.map(async i => ({ status: (await fetch(new URL(i.src, url))).status, size: i.sizes }))) }; });
    expect(manifest.scope).toBe('/CalorieCut/'); expect(manifest.display).toBe('standalone'); expect(manifest.icons.every(i => i.status === 200)).toBeTruthy(); expect(manifest.icons.some(i => i.size === '512x512')).toBeTruthy();
    await context.setOffline(true); await page.reload();
    await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '150 of 1,900 calories');
  } finally { await site.close(); }
});
test('app upgrades preserve diary data and unrelated offline caches', async ({ page, context }) => {
  const site = await staticSite();
  try {
    await onboard(page, site.url); await logEgg(page); await controlled(page);
    await page.evaluate(async () => { await caches.open('caloriecut-/another-app/-keep'); });
    site.upgrade();
    await page.evaluate(async () => { const registration = await navigator.serviceWorker.getRegistration(); await registration.update(); });
    await expect.poll(() => page.evaluate(async () => !!(await navigator.serviceWorker.getRegistration()).waiting)).toBe(true);
    await page.reload(); await expect(page.locator('meta[name="site-version"]')).toHaveAttribute('content', '1');
    await page.close();
    const next = await context.newPage(); await next.goto(site.url); await controlled(next);
    await expect(next.locator('meta[name="site-version"]')).toHaveAttribute('content', '2');
    await expect(next.locator('.energy-ring')).toHaveAttribute('aria-label', '150 of 1,900 calories');
    const caches = await next.evaluate(() => window.caches.keys());
    expect(caches).toContain('caloriecut-/another-app/-keep'); expect(caches).toContain('caloriecut-/CalorieCut/-update-test-v2'); expect(caches).not.toContain('caloriecut-/CalorieCut/-update-test-v1');
    await context.setOffline(true); await next.reload(); await expect(next.locator('meta[name="site-version"]')).toHaveAttribute('content', '2');
  } finally { await site.close(); }
});
