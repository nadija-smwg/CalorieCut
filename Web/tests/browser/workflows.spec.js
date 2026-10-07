import { test, expect } from '@playwright/test';
import { readFile } from 'node:fs/promises';
import { onboard, nav, logEgg, localDay } from './helpers.js';
import { emptyDiary, defaultProfile, uid, now } from '../../src/core.js';

test('favorites and library edits/deletions preserve historical nutrition', async ({ page }) => {
  await onboard(page); await logEgg(page);
  await page.getByRole('button', { name: 'Add food to Breakfast' }).click();
  await page.getByRole('button', { name: 'Favorite Boiled Egg', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Unfavorite Boiled Egg', exact: true })).toHaveAttribute('aria-pressed', 'true');
  await page.getByRole('button', { name: 'Favorites', exact: true }).click();
  await expect(page.locator('#food-results .library-row')).toHaveCount(1);
  await page.getByRole('button', { name: 'Edit Boiled Egg', exact: true }).click();
  await page.getByLabel('Calories (kcal)', { exact: true }).fill('100');
  await page.getByRole('button', { name: 'Save changes', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible();
  await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '150 of 1,900 calories');
  await page.getByRole('button', { name: 'Add food to Breakfast' }).click();
  await page.getByLabel('Search foods').fill('Boiled Egg');
  await page.getByRole('button', { name: 'Boiled Egg 1 egg · 100 kcal', exact: true }).click();
  await page.getByRole('button', { name: 'Add to diary', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible();
  await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '250 of 1,900 calories');
  await page.getByRole('button', { name: 'Add food to Breakfast' }).click();
  await page.getByRole('button', { name: 'Edit Boiled Egg', exact: true }).click();
  await page.getByRole('button', { name: 'Delete library food', exact: true }).click();
  await page.getByRole('button', { name: 'Confirm', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible();
  await expect(page.locator('.food-row')).toHaveCount(2);
  await page.reload(); await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '250 of 1,900 calories');
});

test('duplicate, move and copy entries retain independent snapshots on calendar days', async ({ page }) => {
  await onboard(page); await logEgg(page);
  await page.locator('.food-row').click(); await page.getByRole('button', { name: 'Duplicate', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible(); await expect(page.locator('.food-row')).toHaveCount(2);
  await page.locator('.food-row').last().click();
  const yesterday = await localDay(page, -1);
  await page.getByLabel('Date & time', { exact: true }).fill(`${yesterday}T12:00`);
  await page.getByLabel('Meal', { exact: true }).selectOption('Dinner');
  await page.getByRole('button', { name: 'Save changes', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible(); await expect(page.locator('.food-row')).toHaveCount(1);
  await page.locator('.food-row').click(); await page.getByRole('button', { name: 'Copy to another day', exact: true }).click();
  await page.getByLabel('Copy to', { exact: true }).fill(yesterday); await page.getByLabel('Meal', { exact: true }).selectOption('Lunch');
  await page.getByRole('button', { name: 'Copy entry', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible(); await nav(page, 'diary');
  await page.getByLabel('Diary date', { exact: true }).fill(yesterday);
  await expect(page.locator('.food-row')).toHaveCount(2); await expect(page.locator('.diary-summary')).toContainText('300');
  await expect(page.locator('.calendar-day.selected')).toHaveAttribute('data-day', yesterday);
  await page.getByRole('button', { name: 'Previous month', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Next month', exact: true })).toBeEnabled();
  await page.getByRole('button', { name: 'Next month', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Next month', exact: true })).toBeDisabled();
});

test('saved meal composition, portions, editing and deletion preserve logged meals', async ({ page }) => {
  await onboard(page); await page.getByRole('button', { name: 'Add food to Lunch' }).click();
  await page.getByRole('button', { name: 'Create saved meal', exact: false }).click();
  await page.getByLabel('Meal name', { exact: true }).fill('Rice and egg');
  await page.getByRole('button', { name: 'Save meal', exact: true }).click();
  await expect(page.getByRole('alert')).toContainText('Invalid saved meal');
  await page.getByRole('checkbox', { name: /Boiled Egg/ }).check();
  await page.getByRole('checkbox', { name: /Cooked White Rice/ }).check();
  await page.getByLabel('Servings of Cooked White Rice', { exact: true }).fill('2');
  await page.getByRole('button', { name: 'Save meal', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible();
  await page.getByRole('button', { name: 'Add food to Lunch' }).click(); await page.getByRole('button', { name: 'Saved meals', exact: true }).click();
  await page.getByRole('button', { name: 'Rice and egg 2 foods · 475 kcal', exact: true }).click();
  await page.getByLabel('Meal portions', { exact: true }).fill('2'); await page.getByRole('button', { name: 'Add meal to diary', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible(); await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '950 of 1,900 calories');
  await page.getByRole('button', { name: 'Add food to Lunch' }).click(); await page.getByRole('button', { name: 'Saved meals', exact: true }).click();
  await page.getByRole('button', { name: 'Edit Rice and egg', exact: true }).click();
  await page.getByRole('checkbox', { name: /Cooked White Rice/ }).uncheck(); await page.getByLabel('Servings of Boiled Egg', { exact: true }).fill('3');
  await page.getByRole('button', { name: 'Save meal', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible(); await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '950 of 1,900 calories');
  await page.getByRole('button', { name: 'Add food to Lunch' }).click(); await page.getByRole('button', { name: 'Saved meals', exact: true }).click();
  await expect(page.getByRole('button', { name: 'Rice and egg 1 foods · 225 kcal', exact: true })).toBeVisible();
  await page.getByRole('button', { name: 'Edit Rice and egg', exact: true }).click(); await page.getByRole('button', { name: 'Delete saved meal', exact: true }).click();
  await page.getByRole('button', { name: 'Confirm', exact: true }).click(); await expect(page.locator('#modal')).not.toBeVisible();
  await expect(page.locator('.food-row')).toHaveCount(2);
});

test('imperial profile boundaries, waist-only measurements and deletion are usable', async ({ page }) => {
  await onboard(page); await nav(page, 'settings');
  await page.getByLabel('Weight unit', { exact: true }).selectOption('lb'); await page.getByLabel('Length unit', { exact: true }).selectOption('in');
  await page.getByRole('button', { name: 'Save preferences', exact: true }).click(); await expect(page.getByRole('status')).toContainText('Preferences saved');
  await page.getByRole('button', { name: 'Edit goals', exact: true }).click();
  await page.getByLabel('Height (in)', { exact: true }).fill('98.4252'); await page.getByLabel('Current weight (lb)', { exact: true }).fill('66.1387');
  await page.getByLabel('Target weight (lb)', { exact: true }).fill('66.1387'); await page.getByLabel('Waist (in)', { exact: true }).fill('98.4252');
  await page.getByRole('button', { name: 'Save profile & goals', exact: true }).click(); await expect(page.locator('#modal')).not.toBeVisible();
  const downloadPromise = page.waitForEvent('download'); await page.getByRole('button', { name: 'Export backup', exact: true }).click();
  const download = await downloadPromise, saved = JSON.parse(await readFile(await download.path(), 'utf8'));
  expect(saved.profile.values.weight).toBe(30); expect(saved.profile.values.height).toBe(250); expect(saved.measurements[0].weight).toBe(65);
  await nav(page, 'progress'); await page.getByRole('button', { name: 'Add measurement', exact: true }).click();
  await page.getByRole('button', { name: 'Save measurement', exact: true }).click(); await expect(page.getByRole('alert')).toContainText('Invalid measurement');
  await page.getByLabel('Waist (in)', { exact: true }).fill('32.2835'); await page.getByRole('button', { name: 'Save measurement', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible(); await expect(page.locator('.measurement-row')).toHaveCount(2);
  await page.locator('.measurement-row').filter({ hasText: 'A moment to check in' }).click();
  await page.getByLabel('Waist (in)', { exact: true }).fill('33'); await page.getByRole('button', { name: 'Save measurement', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible(); await page.locator('.measurement-row').filter({ hasText: '33 in waist' }).click();
  await page.getByRole('button', { name: 'Delete measurement', exact: true }).click(); await page.getByRole('button', { name: 'Confirm', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible(); await expect(page.locator('.measurement-row')).toHaveCount(1);
});

test('water history removes logs, and network changes preserve unsaved notes', async ({ page, context }) => {
  await onboard(page); await page.getByRole('button', { name: 'Custom water amount', exact: true }).click();
  await page.getByLabel('Water (ml)', { exact: true }).fill('375'); await page.getByRole('button', { name: 'Add water', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible(); await page.getByRole('button', { name: 'View water logs', exact: true }).click();
  await expect(page.locator('.library-row')).toContainText('375 ml'); await page.getByRole('button', { name: 'Remove', exact: true }).click();
  await expect(page.getByText('No water logged on this day.', { exact: true })).toBeVisible(); await page.getByRole('button', { name: 'Close dialog', exact: true }).click();
  await nav(page, 'diary'); await page.getByLabel('How did your day feel?').fill('Keep this draft.'); await page.getByLabel('Steps (optional)').fill('1234');
  await page.evaluate(() => navigator.serviceWorker.ready); await context.setOffline(true);
  await expect(page.locator('.connection')).toContainText('Offline'); await expect(page.getByLabel('How did your day feel?')).toHaveValue('Keep this draft.');
  await page.getByRole('button', { name: 'Save notes', exact: true }).click(); await expect(page.getByRole('status')).toContainText('Notes saved');
  await page.reload(); await expect(page.getByLabel('How did your day feel?')).toHaveValue('Keep this draft.');
});

test('failed storage writes preserve the previous diary without uncaught errors', async ({ page }) => {
  const errors = []; page.on('pageerror', e => errors.push(e.message));
  await onboard(page); await logEgg(page);
  await page.evaluate(() => { const put = IDBObjectStore.prototype.put; IDBObjectStore.prototype.put = function(value, ...args) { if (value?.water?.length) throw new DOMException('Storage full', 'QuotaExceededError'); return put.call(this, value, ...args); }; });
  await page.getByRole('button', { name: '250 ml', exact: false }).click();
  await expect(page.getByRole('status')).toContainText('Could not save'); await expect(page.locator('.water-value')).toContainText('0 /');
  await page.reload(); await expect(page.locator('.energy-ring')).toHaveAttribute('aria-label', '150 of 1,900 calories'); await expect(page.locator('.water-value')).toContainText('0 /');
  expect(errors).toEqual([]);
});

test('corrupt stored data is preserved and can be exported for recovery', async ({ page }) => {
  await onboard(page);
  await page.evaluate(() => new Promise((resolve, reject) => { const request = indexedDB.open('caloriecut', 1); request.onsuccess = () => { const db = request.result, tx = db.transaction('diary', 'readwrite'); tx.objectStore('diary').put({ version: 999, original: 'keep me' }, 'current'); tx.oncomplete = () => { db.close(); resolve(); }; tx.onerror = reject; }; request.onerror = reject; }));
  await page.reload(); await expect(page.getByRole('heading', { name: 'Your diary needs a moment.' })).toBeVisible();
  const downloadPromise = page.waitForEvent('download'); await page.getByRole('button', { name: 'Export stored data for recovery', exact: true }).click();
  const download = await downloadPromise, saved = JSON.parse(await readFile(await download.path(), 'utf8'));
  expect(saved).toEqual({ version: 999, original: 'keep me' });
  await page.getByRole('button', { name: 'Try again', exact: true }).click(); await expect(page.getByText('Your saved data has not been overwritten.')).toBeVisible();
});

test('chart ranges honor chronological spacing and display the underlying values', async ({ page }) => {
  await page.goto('/');
  const backup = emptyDiary(); backup.profile = { id: uid(), createdAt: now(), values: { ...defaultProfile, name: 'Alex' } };
  for (const [offset, weight] of [[-60, 68], [-20, 67], [-5, 66], [-1, 65]]) {
    const day = await localDay(page, offset);
    backup.measurements.push({ id: uid(), date: `${day}T12:00:00Z`, weight, waist: 82, notes: '' });
  }
  const chooser = page.waitForEvent('filechooser'); await page.getByRole('button', { name: 'Restore a backup', exact: true }).click();
  await (await chooser).setFiles({ name: 'trend.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify(backup)) });
  await page.getByRole('button', { name: 'Confirm', exact: true }).click(); await expect(page.locator('#modal')).not.toBeVisible(); await nav(page, 'progress');
  await expect(page.locator('.chart-point')).toHaveCount(3);
  expect(Number(await page.locator('.chart-point').nth(1).getAttribute('cx'))).toBeGreaterThan(460);
  await page.getByRole('combobox', { name: 'Chart date range', exact: true }).selectOption('7'); await expect(page.locator('.chart-point')).toHaveCount(2);
  await page.getByRole('combobox', { name: 'Chart date range', exact: true }).selectOption('all'); await expect(page.locator('.chart-point')).toHaveCount(4);
  await page.getByText('View weight data', { exact: true }).click(); await expect(page.locator('.chart-data tbody tr')).toHaveCount(4); await expect(page.locator('.chart-data tbody')).toContainText('68');
  await page.getByRole('button', { name: 'Waist', exact: true }).click(); await expect(page.getByRole('img', { name: /Waist chart with 4 records/ })).toBeVisible();
});

test('food names are displayed as text and the app makes no external page requests', async ({ page }) => {
  const external = []; page.on('request', request => { if (new URL(request.url()).origin !== 'http://127.0.0.1:4173') external.push(request.url()); });
  await onboard(page); await page.getByRole('button', { name: 'Add food to Breakfast', exact: true }).click(); await page.getByRole('button', { name: 'New food', exact: false }).click();
  const name = '<img src=x onerror="window.injected=1">';
  await page.getByLabel('Food name', { exact: true }).fill(name); await page.getByLabel('Calories (kcal)', { exact: true }).fill('100');
  await page.getByRole('button', { name: 'Add to diary', exact: true }).click(); await expect(page.locator('#modal')).not.toBeVisible();
  await expect(page.locator('.food-row')).toContainText(name); await expect(page.locator('#app img')).toHaveCount(0);
  expect(await page.evaluate(() => window.injected)).toBeUndefined();
  for (const view of ['diary', 'progress', 'review', 'settings']) await nav(page, view);
  expect(external).toEqual([]);
});
