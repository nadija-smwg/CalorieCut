import { defineConfig } from '@playwright/test';
import { existsSync } from 'node:fs';
// CI uses the browser revision installed by the locked Playwright version.
// Local development can reuse system Chromium; an explicit override wins in either mode.
const executablePath = process.env.CHROMIUM_PATH || (!process.env.CI && existsSync('/usr/bin/chromium') ? '/usr/bin/chromium' : undefined);
export default defineConfig({
  testDir: './tests/browser',
  fullyParallel: false,
  workers: 2,
  forbidOnly: !!process.env.CI,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: { baseURL: 'http://127.0.0.1:4173', timezoneId: 'Asia/Colombo', trace: 'retain-on-failure', screenshot: 'only-on-failure', launchOptions: { executablePath, args: ['--no-sandbox'] } },
  webServer: { command: 'npm run preview -- --port 4173 --strictPort', url: 'http://127.0.0.1:4173', reuseExistingServer: !process.env.CI },
  projects: [
    { name: 'desktop', use: { viewport: { width: 1440, height: 1000 } } },
    { name: 'mobile', use: { viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true } },
    ...(process.env.CALORIECUT_WEBKIT === '1' ? [{ name: 'safari', use: { browserName: 'webkit', launchOptions: {}, viewport: { width: 390, height: 844 }, isMobile: true, hasTouch: true } }] : [])
  ]
});
