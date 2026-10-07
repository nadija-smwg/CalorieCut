import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import { onboard, nav } from './helpers.js';
test('screens and profile form meet automated accessibility checks in light and dark mode', async ({ page }) => {
  await onboard(page);
  // Status text keeps full contrast throughout its visible lifetime.
  await expect(page.locator('#toast')).toHaveCSS('opacity', '1');
  await expect(page.locator('#toast')).toHaveCSS('transition-property', 'transform');
  async function check(label) {
    const result = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa']).analyze();
    expect(result.violations.map(v => ({ id: v.id, impact: v.impact, selectors: v.nodes.map(n => n.target) })), label).toEqual([]);
  }
  for (const view of ['home', 'diary', 'progress', 'review', 'settings']) { await nav(page, view); await check(view); }
  await page.getByLabel('Appearance', { exact: true }).selectOption('Dark'); await page.getByRole('button', { name: 'Save preferences', exact: true }).click();
  await expect(page.getByRole('status')).toContainText('Preferences saved'); await check('dark settings');
  await page.getByRole('button', { name: 'Edit goals', exact: true }).click(); await check('profile form');
});
