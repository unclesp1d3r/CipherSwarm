import { test, expect } from '@playwright/test';

test('layout renders Sidebar', async ({ page }) => {
    await page.goto('/');

    // Sidebar link
    await expect(page.getByRole('link', { name: 'Dashboard' })).toBeVisible();
}); 