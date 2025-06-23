import { expect, test } from '@playwright/test';

test('layout renders Sidebar', async ({ page }) => {
    await page.goto('/');

    // Sidebar button (not link) - the sidebar uses MenuButton components
    await expect(page.getByRole('button', { name: 'Dashboard' })).toBeVisible();
});
