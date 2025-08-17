import { test, expect } from '@playwright/test';

test.describe('Campaign Detail Page', () => {
    test('displays campaign information correctly', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Check campaign name and description
        await expect(page.getByTestId('campaign-name')).toHaveText('Test Campaign');
        await expect(page.getByTestId('campaign-description')).toHaveText(
            'A test campaign for validation'
        );

        // Check campaign state badge
        await expect(page.getByTestId('campaign-state')).toHaveText('Draft');

        // Check progress bar is displayed (only if progress > 0)
        // Since mock data has progress: 25, the progress bar should be visible
        await expect(page.getByTestId('campaign-progress')).toBeVisible();
    });

    test('displays attacks table with correct data', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Check that attacks table is visible
        await expect(page.getByTestId('attacks-table')).toBeVisible();

        // Check attack rows
        await expect(page.getByTestId('attack-row-1')).toBeVisible();
        await expect(page.getByTestId('attack-row-2')).toBeVisible();

        // Check attack data
        const firstRow = page.getByTestId('attack-row-1');
        await expect(firstRow).toContainText('Dictionary');
        await expect(firstRow).toContainText('English');
        await expect(firstRow).toContainText('8');
        await expect(firstRow).toContainText('Default wordlist with basic rules');
        await expect(firstRow).toContainText('1,000,000');

        const secondRow = page.getByTestId('attack-row-2');
        await expect(secondRow).toContainText('Brute Force');
        await expect(secondRow).toContainText('4');
        await expect(secondRow).toContainText('Lowercase, Uppercase, Numbers');
        await expect(secondRow).toContainText('78,914,410');
    });

    test('handles empty campaign with no attacks', async ({ page }) => {
        // Use campaign ID 2 which returns empty campaign in SSR
        await page.goto('/campaigns/2');

        await expect(page.getByTestId('no-attacks')).toBeVisible();
        await expect(page.getByTestId('no-attacks')).toHaveText(
            'No attacks configured for this campaign.'
        );
        await expect(page.getByTestId('remove-all-attacks')).not.toBeVisible();
    });

    test('shows correct action buttons based on campaign state', async ({ page }) => {
        // Test draft state - should show start button
        await page.goto('/campaigns/1');
        await expect(page.getByTestId('start-campaign')).toBeVisible();
        await expect(page.getByTestId('stop-campaign')).not.toBeVisible();

        // For testing running state, we would need a different campaign ID or test scenario
        // This would require updating the server mock data to handle different states
    });

    test('attack dropdown menu works correctly', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Click the dropdown menu for first attack
        await page.getByTestId('attack-menu-1').click();

        // Check that all menu items are visible
        await expect(page.getByText('Edit')).toBeVisible();
        await expect(page.getByText('Duplicate')).toBeVisible();
        await expect(page.getByText('Move Up')).toBeVisible();
        await expect(page.getByText('Move Down')).toBeVisible();
        await expect(page.getByText('Remove')).toBeVisible();
    });

    test('navigates back to campaigns list', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Click back to campaigns button
        await page.getByText('← Back to Campaigns').click();

        // Check that we're redirected to campaigns list
        await expect(page).toHaveURL('/campaigns');
    });
});
