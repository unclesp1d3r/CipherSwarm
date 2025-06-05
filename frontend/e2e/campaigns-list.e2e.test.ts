import { test, expect } from '@playwright/test';

const campaignsResponse = {
    items: [
        {
            id: 1,
            name: 'Campaign Alpha',
            progress: 42,
            state: 'running',
            summary: '3 attacks / 2 running / ETA 4h',
            attacks: []
        },
        {
            id: 2,
            name: 'Sensitive Campaign',
            progress: 100,
            state: 'completed',
            summary: '2 attacks / 0 running / ETA 0h',
            attacks: []
        }
    ],
    total: 2
};

test.describe('Campaigns List Page', () => {
    test('renders campaigns and attacks from API', async ({ page }) => {
        // Set up route mock before navigation
        await page.route('/api/v1/web/campaigns*', route => {
            route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify(campaignsResponse),
            });
        });

        await page.goto('/campaigns');
        await expect(page.getByTestId('campaigns-title')).toBeVisible();

        // Verify we don't see the loading state
        await expect(page.getByText('Loading campaigns…')).not.toBeVisible();

        // Verify we don't see the empty state
        await expect(page.getByText('No campaigns found.')).not.toBeVisible();

        // Verify we don't see the error state
        await expect(page.getByText('Failed to load campaigns.')).not.toBeVisible();

        // Verify campaigns are rendered
        await expect(page.getByText('Campaign Alpha')).toBeVisible();
        await expect(page.getByText('Sensitive Campaign')).toBeVisible();

        // Verify state badges (use first occurrence for each)
        await expect(page.locator('[data-slot="badge"]').filter({ hasText: 'Running' })).toBeVisible();
        await expect(page.locator('[data-slot="badge"]').filter({ hasText: 'Completed' })).toBeVisible();

        // Verify summaries
        await expect(page.getByText('3 attacks / 2 running / ETA 4h')).toBeVisible();
        await expect(page.getByText('2 attacks / 0 running / ETA 0h')).toBeVisible();
    });

    test('shows empty state when no campaigns', async ({ page }) => {
        await page.route('/api/v1/web/campaigns*', route => {
            route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({ items: [], total: 0 })
            });
        });
        await page.goto('/campaigns');
        await expect(page.getByText('No campaigns found.')).toBeVisible();
        await expect(page.getByRole('button', { name: /create campaign/i })).toBeVisible();
    });

    test('shows error state on API failure', async ({ page }) => {
        await page.route('/api/v1/web/campaigns*', route => {
            route.fulfill({ status: 500, contentType: 'application/json', body: '{}' });
        });
        await page.goto('/campaigns');
        await expect(page.getByText('Failed to load campaigns.')).toBeVisible();
    });
}); 