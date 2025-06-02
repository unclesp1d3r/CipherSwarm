import { test, expect } from '@playwright/test';

test.describe('/agents page', () => {
    test('renders agent table, search, and actions', async ({ page }) => {
        await page.goto('/agents');
        await expect(page.getByRole('heading', { name: 'Agents' })).toBeVisible();
        await expect(page.getByPlaceholder('Search agents...')).toBeVisible();
        await expect(page.getByText('Agent-01')).toBeVisible();
        await expect(page.getByText('Agent-02')).toBeVisible();
        await expect(page.getByText('Agent-03')).toBeVisible();
        await expect(page.getByText('Register Agent')).toBeVisible();
    });

    test('filters agents by search input', async ({ page }) => {
        await page.goto('/agents');
        const input = page.getByPlaceholder('Search agents...');
        await input.fill('Agent-01');
        await expect(page.getByText('Agent-01')).toBeVisible();
        await expect(page.locator('text=Agent-02').isVisible()).resolves.toBeFalsy();
        await expect(page.locator('text=Agent-03').isVisible()).resolves.toBeFalsy();
    });

    test('shows empty state if no agents match', async ({ page }) => {
        await page.goto('/agents');
        const input = page.getByPlaceholder('Search agents...');
        await input.fill('notfound');
        await expect(page.getByText('No agents found.')).toBeVisible();
    });

    test('opens Register Agent modal', async ({ page }) => {
        await page.goto('/agents');
        await page.getByText('Register Agent').click();
        await expect(page.getByText('Register New Agent')).toBeVisible();
        await expect(page.getByText('Registration form goes here.')).toBeVisible();
    });
}); 