import { test, expect } from '@playwright/test';

test('home page has expected dashboard elements', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByText('Active Agents')).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Campaign Overview' })).toBeVisible();
});
