// Serves ../ (the site) on a local port and runs site.spec.mjs against it in headless Chromium.
import { defineConfig, devices } from '@playwright/test';

const port = 4178;

export default defineConfig({
  testDir: '.',
  testMatch: /.*\.spec\.mjs/,
  timeout: 30_000,
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['github']] : 'list',
  use: {
    baseURL: `http://127.0.0.1:${port}/`,
    trace: 'retain-on-failure',
  },
  // The site is static: Python's http.server is enough, and it's on every macOS and CI runner.
  webServer: {
    command: `python3 -m http.server ${port} --bind 127.0.0.1 --directory ..`,
    url: `http://127.0.0.1:${port}/index.html`,
    reuseExistingServer: !process.env.CI,
    timeout: 20_000,
  },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1440, height: 900 } } },
    { name: 'phone', use: { ...devices['Pixel 7'] } },
  ],
});
