import { expect, test } from '@playwright/test';

test('layout renders Sidebar, Header, and Avatar', async ({ page }) => {
    await page.goto('/');

    // Wait for main content to ensure hydration
    await expect(page.locator('h1')).toBeVisible();

    // Sidebar links
    await expect(page.getByRole('link', { name: 'Dashboard' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Campaigns' })).toBeVisible();
    await expect(page.getByRole('link', { name: 'Agents' })).toBeVisible();

    // Header project selector
    await expect(page.locator('select')).toBeVisible();
    // User avatar (should be present)
    await expect(page.locator('[data-slot="avatar"]')).toBeVisible();
}); 