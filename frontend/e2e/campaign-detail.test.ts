import { test, expect } from '@playwright/test';

test.describe('Campaign Detail Page', () => {
    test('displays campaign details correctly', async ({ page }) => {
        // Navigate to campaign detail page with test environment
        await page.goto('/campaigns/1');

        // Check that the page loads and displays campaign information
        await expect(page.getByTestId('campaign-name')).toHaveText('Test Campaign');
        await expect(page.getByTestId('campaign-description')).toHaveText(
            'A test campaign for validation'
        );
        await expect(page.getByTestId('campaign-state')).toHaveText('Draft');

        // Check that the progress bar is displayed
        await expect(page.getByTestId('campaign-progress')).toBeVisible();

        // Check that attacks table is displayed
        await expect(page.getByTestId('attacks-table')).toBeVisible();

        // Check that attacks are displayed
        await expect(page.getByTestId('attack-row-1')).toBeVisible();
        await expect(page.getByTestId('attack-row-2')).toBeVisible();
    });

    test('displays no attacks message when campaign has no attacks', async ({ page }) => {
        // Navigate to campaign detail page with empty attacks
        await page.goto('/campaigns/2');

        // Check that no attacks message is displayed
        await expect(page.getByTestId('no-attacks')).toBeVisible();
        await expect(page.getByTestId('no-attacks')).toHaveText(
            'No attacks configured for this campaign.'
        );
    });

    test('handles campaign not found', async ({ page }) => {
        // Navigate to non-existent campaign
        await page.goto('/campaigns/999');

        // Check that not found message is displayed
        await expect(page.getByTestId('not-found')).toBeVisible();
        await expect(page.getByTestId('not-found')).toHaveText('Campaign not found.');
    });

    test('displays campaign action buttons correctly', async ({ page }) => {
        // Navigate to draft campaign
        await page.goto('/campaigns/1');

        // Check that start campaign button is visible for draft campaigns
        await expect(page.getByTestId('start-campaign')).toBeVisible();

        // Check that add attack button is visible
        await expect(page.getByTestId('add-attack')).toBeVisible();

        // Check that remove all attacks button is visible when attacks exist
        await expect(page.getByTestId('remove-all-attacks')).toBeVisible();
    });

    test('displays attack menu and actions', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Click on the first attack menu
        await page.getByTestId('attack-menu-1').click();

        // Check that menu items are visible
        await expect(page.getByText('Edit')).toBeVisible();
        await expect(page.getByText('Duplicate')).toBeVisible();
        await expect(page.getByText('Move Up')).toBeVisible();
        await expect(page.getByText('Move Down')).toBeVisible();
        await expect(page.getByText('Move to Top')).toBeVisible();
        await expect(page.getByText('Move to Bottom')).toBeVisible();
        await expect(page.getByText('Remove')).toBeVisible();
    });

    test('navigates back to campaigns list', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Click back to campaigns button
        await page.getByText('← Back to Campaigns').click();

        // Check that we're redirected to campaigns list
        await expect(page).toHaveURL('/campaigns');
    });

    test('handles test error scenario', async ({ page }) => {
        // Navigate to campaign detail page with error scenario
        await page.goto('/campaigns/1?test_scenario=error');

        // Check that error page is displayed (500 error should be handled by SvelteKit)
        await expect(page.locator('body')).toContainText('500');
    });

    test('handles test not found scenario', async ({ page }) => {
        // Navigate to campaign detail page with not found scenario
        await page.goto('/campaigns/1?test_scenario=not_found');

        // Check that not found page is displayed (404 error should be handled by SvelteKit)
        await expect(page.locator('body')).toContainText('404');
    });
});
