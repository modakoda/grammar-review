// The landing page in a real browser: it loads cleanly at desktop and phone widths, the demos
// work, and the download section handles no release, a notarized release and an unsigned one.
import { expect, test } from '@playwright/test';

const RELEASE = {
  version: '0.2.0',
  published: '2026-10-21T09:30:00Z',
  minimumSystemVersion: '14.0',
  notarized: true,
  files: {
    dmg: { name: 'Grammar-Review.dmg', size: 5_300_000, sha256: 'a'.repeat(64) },
    zip: { name: 'Grammar-Review.zip', size: 4_900_000, sha256: 'b'.repeat(64) },
  },
};

/** Collects console errors and failed requests other than the optional latest.json. */
function watch(page) {
  const problems = [];
  page.on('console', (m) => { if (m.type() === 'error') problems.push(`console: ${m.text()}`); });
  page.on('pageerror', (e) => problems.push(`pageerror: ${e.message}`));
  page.on('requestfailed', (r) => { if (!r.url().includes('latest.json')) problems.push(`request failed: ${r.url()}`); });
  return problems;
}

async function open(page, { release } = {}) {
  if (release !== undefined) {
    await page.route('**/download/latest.json', (route) =>
      release === null
        ? route.fulfill({ status: 404, body: 'not found' })
        : route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(release) })
    );
  }
  // Fonts come from Google; the tests must not depend on the network.
  await page.route(/fonts\.(googleapis|gstatic)\.com/, (route) => route.fulfill({ status: 200, contentType: 'text/css', body: '' }));
  const problems = watch(page);
  await page.goto('index.html');
  await page.waitForLoadState('load');
  return problems;
}

test.describe('page', () => {
  test('loads without errors and without horizontal scrolling', async ({ page }) => {
    const problems = await open(page, { release: null });
    await expect(page).toHaveTitle('Grammar Review');
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
    expect(overflow).toBeLessThanOrEqual(1);
    // Scroll through so lazy effects run, then check again.
    await page.evaluate(async () => {
      for (let y = 0; y < document.body.scrollHeight; y += 700) { window.scrollTo(0, y); await new Promise((r) => setTimeout(r, 40)); }
      window.scrollTo(0, 0);
    });
    expect(await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth)).toBeLessThanOrEqual(1);
    // Chrome logs the missing latest.json itself as a 404; that is the only expected message.
    expect(problems.filter((p) => !/latest\.json|404/.test(p))).toEqual([]);
  });

  test('every section is reachable from the nav', async ({ page, isMobile }) => {
    test.skip(isMobile, 'the nav links are hidden at phone width');
    await open(page, { release: null });
    for (const [label, id] of [['Try it', 'demo'], ['Features', 'features'], ['Editor', 'editor'], ['Models', 'models'], ['Privacy', 'privacy'], ['FAQ', 'faq']]) {
      await page.getByRole('navigation', { name: 'Sections' }).getByRole('link', { name: label }).click();
      await expect(page).toHaveURL(new RegExp(`#${id}$`));
      await expect(page.locator(`#${id}`)).toBeInViewport({ ratio: 0.05 });
    }
  });

  test('the headline heals its misspelling', async ({ page }) => {
    await open(page, { release: null });
    const heal = page.locator('#heal');
    await expect(heal).toHaveClass(/fixed/, { timeout: 5_000 });
    await expect(heal.locator('.r')).toHaveText('sentence');
    await page.getByRole('button', { name: /replay the headline/i }).click();
    await expect(heal).toHaveClass(/fixed/, { timeout: 5_000 });
  });

  test('respects reduced motion', async ({ browser }) => {
    const context = await browser.newContext({ reducedMotion: 'reduce' });
    const page = await context.newPage();
    const problems = await open(page, { release: null });
    await expect(page.locator('#heal')).toHaveClass(/fixed/);
    // Reveal-on-scroll is off: everything is visible at once.
    const hidden = await page.evaluate(() => Array.from(document.querySelectorAll('.reveal')).filter((e) => getComputedStyle(e).opacity !== '1').length);
    expect(hidden).toBe(0);
    expect(problems.filter((p) => !/latest\.json|404/.test(p))).toEqual([]);
    await context.close();
  });
});

test.describe('overlay demo', () => {
  test('accepting fixes updates the text, the badge and the panel', async ({ page }) => {
    await open(page, { release: null });
    const field = page.locator('#fieldText');
    const badge = page.locator('#badgeCount');
    await expect(badge).toHaveText('7');
    await expect(page.locator('#panelTitle')).toHaveText('7 suggestions');
    await expect(page.locator('#toneLine')).toContainText('Appreciative', { timeout: 5_000 });

    const first = field.locator('.iss').first();
    await expect(first).toHaveText('past');
    await first.click();
    const card = page.locator('#card');
    await expect(card).toBeVisible();
    await expect(card).toContainText('Passed');
    await card.getByRole('button', { name: 'Accept' }).click();
    await expect(field).toContainText('release passed every test');
    await expect(badge).toHaveText('6');
    await expect(card).toBeHidden();

    // Ignore from the panel, then restore.
    await page.locator('#panelList').getByRole('button', { name: 'Ignore' }).first().click();
    await expect(badge).toHaveText('5');
    await expect(page.locator('#ignored')).toBeVisible();
    await page.locator('#ignoredList').getByRole('button', { name: 'Restore' }).click();
    await expect(badge).toHaveText('6');

    // Fix all handles the red ones only.
    await page.locator('#fixAll').click();
    await expect(page.locator('#fixAll')).toBeHidden({ timeout: 10_000 });
    await expect(field).toContainText('There were');
    await expect(field).toContainText('It’s');
    await expect(badge).toHaveText('3');
    await expect(field.locator('.iss[data-sev="correctness"]')).toHaveCount(0);

    await page.locator('#replayDemo').click();
    await expect(badge).toHaveText('7');
    await expect(field).toContainText('release past every test');
  });

  test('the editor sidebar tabs switch with the mouse and the keyboard', async ({ page }) => {
    await open(page, { release: null });
    await page.locator('#tab-ins').click();
    await expect(page.locator('#pane-ins')).toBeVisible();
    await expect(page.locator('#pane-sug')).toBeHidden();
    await expect(page.locator('#pane-ins')).toContainText('Readability');
    await page.keyboard.press('ArrowLeft');
    await expect(page.locator('#pane-sug')).toBeVisible();
    await expect(page.locator('#tab-sug')).toHaveAttribute('aria-selected', 'true');
  });
});

test.describe('download', () => {
  test('before the first release the page says so and offers the source', async ({ page }) => {
    await open(page, { release: null });
    await expect(page.locator('#download')).toHaveAttribute('data-state', 'soon');
    await expect(page.locator('#heroDlMeta')).toContainText('First release coming soon');
    await expect(page.locator('#dlStepTitle')).toHaveText('Build and open');
    await expect(page.locator('#download .ready-only')).toBeHidden();
    await expect(page.locator('#download .soon-only')).toBeVisible();
    await expect(page.locator('#dlSha')).toBeHidden();
    // The buttons point at the download card, not at a missing file.
    for (const href of await page.locator('[data-dl]').evaluateAll((as) => as.map((a) => a.getAttribute('href')))) {
      expect(href).toBe('#download');
    }
  });

  test('a null version in latest.json counts as no release', async ({ page }) => {
    await open(page, { release: { version: null, published: null, minimumSystemVersion: null, notarized: null, files: {} } });
    await expect(page.locator('#download')).toHaveAttribute('data-state', 'soon');
  });

  test('a notarized release fills in the version, size and checksums', async ({ page }) => {
    await open(page, { release: RELEASE });
    await expect(page.locator('#download')).toHaveAttribute('data-state', 'ready');
    await expect(page.locator('#dlMeta')).toHaveText('Version 0.2.0 · macOS 14 or later · 5.3 MB');
    await expect(page.locator('#heroDlMeta')).toHaveText('Version 0.2.0 · macOS 14 or later · 5.3 MB');
    await expect(page.locator('#dlZip')).toHaveText('or get the .zip (4.9 MB)');
    await expect(page.locator('#dlInstall')).toHaveAttribute('data-notarized', 'true');
    await expect(page.locator('#dlInstall .unsigned')).toBeHidden();
    await expect(page.locator('#dlSha')).toBeVisible();
    await page.locator('#dlSha summary').click();
    await expect(page.locator('#dlShaList')).toContainText('a'.repeat(64));
    const hrefs = await page.locator('[data-dl]').evaluateAll((as) => as.map((a) => a.getAttribute('href')));
    expect(new Set(hrefs)).toEqual(new Set(['download/Grammar-Review.dmg']));
    await expect(page.locator('#download .soon-only')).toBeHidden();
  });

  test('an unsigned release shows the Open Anyway step', async ({ page }) => {
    await open(page, { release: { ...RELEASE, notarized: false, minimumSystemVersion: '14.2' } });
    await expect(page.locator('#dlInstall')).toHaveAttribute('data-notarized', 'false');
    await expect(page.locator('#dlInstall .unsigned')).toBeVisible();
    await expect(page.locator('#dlInstall .unsigned')).toContainText('Open Anyway');
    await expect(page.locator('#dlMeta')).toContainText('macOS 14.2 or later');
  });

  test('a broken latest.json falls back to the no-release state', async ({ page }) => {
    await open(page, { release: { version: '<script>x</script>' } });
    await expect(page.locator('#download')).toHaveAttribute('data-state', 'soon');
  });
});

test('screenshots for a look', async ({ page }, testInfo) => {
  await open(page, { release: RELEASE });
  await page.evaluate(() => document.querySelectorAll('.reveal').forEach((e) => e.classList.add('in')));
  await page.waitForTimeout(400);
  await page.screenshot({ path: testInfo.outputPath('full.png'), fullPage: true });
  await testInfo.attach('full page', { path: testInfo.outputPath('full.png'), contentType: 'image/png' });
});
