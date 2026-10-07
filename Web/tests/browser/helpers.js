import { expect } from '@playwright/test';
export async function offlineReload(page, context, browserName, site) {
  // WebKit's protocol offline flag prevents even service-worker navigations.
  // Deny the real origin instead, while retaining protocol offline in Chromium.
  site.disconnect();
  if (browserName === 'webkit') await context.setOffline(false);
  await page.reload();
  expect(await page.evaluate(() => fetch(`./uncached-network-probe?${Date.now()}`).then(() => true, () => false))).toBe(false);
}
export async function onboard(page, path = '/') {
  await page.goto(path); await page.getByRole('button', { name: 'Let’s get started' }).click();
  await page.getByLabel('What should we call you?').fill('Alex');
  await page.getByRole('button', { name: 'Start my diary' }).click();
  await expect(page.locator('#modal')).not.toBeVisible();
  await expect(page.getByRole('heading', { name: 'Your daily balance.' })).toBeVisible();
}
export async function nav(page, key) { await page.locator(`[data-action="nav"][data-view="${key}"]:visible`).first().click(); }
export async function logEgg(page) {
  await page.getByRole('button', { name: 'Add food to Breakfast' }).click();
  await page.getByLabel('Search foods').fill('Boiled Egg');
  await page.getByRole('button', { name: 'Boiled Egg 1 egg · 75 kcal', exact: true }).click();
  await page.getByLabel('Number of servings').fill('2');
  await page.getByRole('button', { name: 'Add to diary', exact: true }).click();
  await expect(page.locator('#modal')).not.toBeVisible();
  await expect(page.locator('.food-row').filter({ hasText: 'Boiled Egg' })).toBeVisible();
}
export async function localDay(page, offset = 0) {
  return page.evaluate(amount => { const d = new Date(); d.setDate(d.getDate() + amount); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; }, offset);
}
