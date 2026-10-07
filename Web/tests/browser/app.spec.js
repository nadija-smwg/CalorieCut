import { test, expect } from '@playwright/test';
import { onboard, nav, logEgg, offlineReload } from './helpers.js';
import { staticSite } from './static-site.js';
test('logs foods and water, edits entries and persists after reload', async ({ page }) => {
  const errors = []; page.on('pageerror', error => errors.push(error.message));
  await onboard(page); await logEgg(page);
  await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '150 of 1,900 calories');
  await page.getByRole('button', { name: '250 ml', exact: false }).click();
  await expect(page.locator('.water-value')).toContainText('0.25');
  await page.locator('.food-row').click(); await page.getByLabel('Number of servings').fill('3'); await page.getByRole('button', { name: 'Save changes', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible();
  await page.reload(); await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '225 of 1,900 calories');
  await expect(page.locator('.water-value')).toContainText('0.25');
  await page.locator('.food-row').click(); await page.getByRole('button', { name: 'Delete entry', exact: true }).click(); await page.getByRole('button', { name: 'Confirm', exact: true }).click();
  await expect(page.locator('.food-row')).toHaveCount(0); expect(errors).toEqual([]);
});
test('custom food, saved meal, notes and measurements work', async ({ page }) => {
  await onboard(page); await nav(page, 'diary');
  await page.getByRole('button', { name: 'Add food to Lunch' }).click(); await page.getByRole('button', { name: 'New food' }).click();
  await page.getByLabel('Food name', { exact: true }).fill('Garden salad'); await page.getByLabel('Calories (kcal)', { exact: true }).fill('180');
  await page.getByLabel('Food category', { exact: true }).selectOption('Vegetable');
  await page.getByRole('button', { name: 'Add to diary', exact: true }).click();
  await page.getByRole('button', { name: 'Save as meal' }).click(); await page.getByLabel('Meal name', { exact: true }).fill('Quick lunch'); await page.getByRole('button', { name: 'Save meal', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible();
  await page.getByLabel('How did your day feel?').fill('A good walk after lunch.'); await page.getByLabel('Steps (optional)').fill('5200'); await page.getByRole('button', { name: 'Save notes' }).click();
  await expect(page.getByRole('status')).toContainText('Notes saved.');
  await nav(page, 'progress'); await page.getByRole('button', { name: 'Add measurement', exact: true }).click(); await page.getByLabel('Weight (kg)', { exact: true }).fill('64.8'); await page.getByRole('button', { name: 'Save measurement', exact: true }).click();
  await expect(page.locator('.measurement-row').filter({ hasText: '64.8 kg' })).toBeVisible();
  await nav(page, 'diary'); await page.getByRole('button', { name: 'Open food library' }).click(); await page.getByRole('button', { name: 'Saved meals', exact: true }).click();
  await page.getByRole('button', { name: 'Quick lunch 1 foods · 180 kcal', exact: true }).click(); await page.getByRole('button', { name: 'Add meal to diary' }).click();
  await expect(page.locator('.food-row')).toHaveCount(2);
  await page.reload(); await expect(page.getByLabel('How did your day feel?')).toHaveValue('A good walk after lunch.'); await expect(page.getByLabel('Steps (optional)')).toHaveValue('5200');
});
test('exports and restores a backup and rejects corrupt imports without changing diary', async ({ page }) => {
  await onboard(page); await logEgg(page); await nav(page, 'settings');
  const downloadPromise = page.waitForEvent('download'); await page.getByRole('button', { name: 'Export backup' }).click(); const download = await downloadPromise;
  const path = await download.path();
  const chooserPromise = page.waitForEvent('filechooser'); await page.getByRole('button', { name: 'Import backup' }).click(); await (await chooserPromise).setFiles({ name: 'broken.json', mimeType: 'application/json', buffer: Buffer.from('{bad') });
  await expect(page.getByRole('status')).toContainText('not a valid JSON');
  await page.getByRole('button', { name: 'Delete all data' }).click(); await page.getByRole('button', { name: 'Confirm', exact: true }).click();
  await expect(page.getByRole('heading', { name: /Find your/ })).toBeVisible();
  const restore = page.waitForEvent('filechooser'); await page.getByRole('button', { name: 'Restore a backup' }).click(); await (await restore).setFiles(path); await page.getByRole('button', { name: 'Confirm', exact: true }).click();
  await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '150 of 1,900 calories');
});
test('offline reload retains diary and can save new entries', async ({ page, context, browserName }) => {
  const site = await staticSite('/');
  try {
    await onboard(page, site.url); await logEgg(page);
    await page.evaluate(async () => { await navigator.serviceWorker.ready; if (!navigator.serviceWorker.controller) await new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, { once: true })); });
    await context.setOffline(true); await expect(page.locator('.connection')).toContainText('Offline');
    await offlineReload(page, context, browserName, site); await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '150 of 1,900 calories');
    // navigator.onLine is a browser hint and can reset on an emulated reload.
    // Verify that an uncached request actually fails while the cached app works.
    expect(await page.evaluate(() => fetch('./uncached-network-probe').then(() => true, () => false))).toBe(false);
    await page.getByRole('button', { name: '250 ml', exact: false }).click(); await expect(page.getByRole('status')).toContainText('Water logged.'); await page.reload(); await expect(page.locator('.water-value')).toContainText('0.25');
  } finally { await site.close(); }
});
test('mobile and desktop layout, preferences, reflection and install guidance', async ({ page }) => {
  await onboard(page);
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBeTruthy();
  await nav(page, 'review'); await expect(page.getByRole('heading', { name: 'A fresh start', exact: true })).toBeVisible();
  await nav(page, 'settings'); await page.getByLabel('Weight unit', { exact: true }).selectOption('lb'); await page.getByLabel('Appearance', { exact: true }).selectOption('Dark'); await page.getByRole('button', { name: 'Save preferences' }).click();
  await expect(page.locator('html')).toHaveAttribute('data-theme', 'dark');
  await page.getByRole('button', { name: 'How to install' }).click(); await expect(page.getByText('iPhone / iPad', { exact: true })).toBeVisible(); await expect(page.getByText('Android', { exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Close dialog' }).click(); await nav(page, 'progress'); await expect(page.locator('.measurement-row')).toContainText('143.3 lb');
});
test('another tab cannot silently overwrite changes', async ({ page, context }) => {
  await onboard(page); const second = await context.newPage(); await second.goto('/'); await expect(second.locator('.energy-ring')).toBeVisible();
  await page.getByRole('button', { name: '250 ml', exact: false }).click(); await expect(page.locator('.water-value')).toContainText('0.25');
  await second.getByRole('button', { name: '250 ml', exact: false }).click(); await expect(second.getByRole('status')).toContainText('changed in another tab');
  await second.reload(); await expect(second.locator('.water-value')).toContainText('0.25');
});
