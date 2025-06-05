import { test, expect } from '@playwright/test';

const mockCampaign = {
    id: 1,
    name: 'Test Campaign',
    description: 'A test campaign for validation',
    state: 'draft',
    progress: 25,
    attacks: [
        {
            id: 1,
            type: 'dictionary',
            language: 'English',
            length_min: 1,
            length_max: 8,
            settings_summary: 'Default wordlist with basic rules',
            keyspace: 1000000,
            complexity_score: 3,
            position: 1,
            comment: 'Initial dictionary attack',
            state: 'pending'
        },
        {
            id: 2,
            type: 'brute_force',
            language: '',
            length_min: 1,
            length_max: 4,
            settings_summary: 'Lowercase, Uppercase, Numbers',
            keyspace: 78914410,
            complexity_score: 4,
            position: 2,
            state: 'pending'
        }
    ],
    created_at: '2023-01-01T00:00:00Z',
    updated_at: '2023-01-01T00:00:00Z'
};

const runningCampaign = {
    ...mockCampaign,
    state: 'running',
    progress: 65
};

const emptyCampaign = {
    ...mockCampaign,
    attacks: []
};

test.describe('Campaign Detail Page', () => {
    test.beforeEach(async ({ page }) => {
        // Mock the API endpoint for fetching campaign details
        await page.route('**/api/v1/web/campaigns/1', async (route) => {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify(mockCampaign)
            });
        });

        // Mock other API endpoints that might be called
        await page.route('**/api/v1/web/attacks/*/duplicate', async (route) => {
            await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
        });

        await page.route('**/api/v1/web/attacks/*/move', async (route) => {
            await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
        });

        await page.route('**/api/v1/web/attacks/*', async (route) => {
            if (route.request().method() === 'DELETE') {
                await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
            }
        });

        await page.route('**/api/v1/web/campaigns/1/clear_attacks', async (route) => {
            await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
        });

        await page.route('**/api/v1/web/campaigns/1/start', async (route) => {
            await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
        });

        await page.route('**/api/v1/web/campaigns/1/stop', async (route) => {
            await route.fulfill({ status: 200, contentType: 'application/json', body: '{}' });
        });
    });

    test('displays campaign information correctly', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Check campaign name and description
        await expect(page.getByTestId('campaign-name')).toHaveText('Test Campaign');
        await expect(page.getByTestId('campaign-description')).toHaveText(
            'A test campaign for validation'
        );

        // Check campaign state badge
        await expect(page.getByTestId('campaign-state')).toHaveText('Draft');

        // Check progress bar is displayed
        await expect(page.getByTestId('campaign-progress-card')).toBeVisible();
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
        await expect(firstRow).toContainText('1 → 8');
        await expect(firstRow).toContainText('Default wordlist with basic rules');
        await expect(firstRow).toContainText('1,000,000');

        const secondRow = page.getByTestId('attack-row-2');
        await expect(secondRow).toContainText('Brute Force');
        await expect(secondRow).toContainText('1 → 4');
        await expect(secondRow).toContainText('Lowercase, Uppercase, Numbers');
        await expect(secondRow).toContainText('78,914,410');
    });

    test('handles empty campaign with no attacks', async ({ page }) => {
        await page.route('**/api/v1/web/campaigns/1', async (route) => {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify(emptyCampaign)
            });
        });

        await page.goto('/campaigns/1');

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

        // Test running state - should show stop button
        await page.route('**/api/v1/web/campaigns/1', async (route) => {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify(runningCampaign)
            });
        });

        await page.reload();
        await expect(page.getByTestId('stop-campaign')).toBeVisible();
        await expect(page.getByTestId('start-campaign')).not.toBeVisible();
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

    test('duplicate attack functionality', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Mock the response for successful duplication
        await page.route('**/api/v1/web/campaigns/1', async (route) => {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    ...mockCampaign,
                    attacks: [...mockCampaign.attacks, { ...mockCampaign.attacks[0], id: 3 }]
                })
            });
        });

        // Click duplicate on first attack
        await page.getByTestId('attack-menu-1').click();
        await page.getByText('Duplicate').click();

        // Wait for the API call to complete
        await page.waitForResponse('**/api/v1/web/attacks/1/duplicate');
    });

    test('move attack functionality', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Click move up on second attack
        await page.getByTestId('attack-menu-2').click();
        await page.getByText('Move Up').click();

        // Wait for the API call to complete
        await page.waitForResponse('**/api/v1/web/attacks/2/move');
    });

    test('remove attack functionality', async ({ page }) => {
        let dialogHandled = false;

        // Handle the confirmation dialog
        page.on('dialog', async (dialog) => {
            expect(dialog.type()).toBe('confirm');
            expect(dialog.message()).toBe('Are you sure you want to remove this attack?');
            await dialog.accept();
            dialogHandled = true;
        });

        await page.goto('/campaigns/1');

        // Click remove on first attack
        await page.getByTestId('attack-menu-1').click();
        await page.getByText('Remove').click();

        // Verify dialog was handled
        expect(dialogHandled).toBe(true);

        // Wait for the API call to complete
        await page.waitForResponse('**/api/v1/web/attacks/1');
    });

    test('remove all attacks functionality', async ({ page }) => {
        let dialogHandled = false;

        // Handle the confirmation dialog
        page.on('dialog', async (dialog) => {
            expect(dialog.type()).toBe('confirm');
            expect(dialog.message()).toBe('Remove all attacks from this campaign?');
            await dialog.accept();
            dialogHandled = true;
        });

        await page.goto('/campaigns/1');

        // Click remove all attacks
        await page.getByTestId('remove-all-attacks').click();

        // Verify dialog was handled
        expect(dialogHandled).toBe(true);

        // Wait for the API call to complete
        await page.waitForResponse('**/api/v1/web/campaigns/1/clear_attacks');
    });

    test('start campaign functionality', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Click start campaign
        await page.getByTestId('start-campaign').click();

        // Wait for the API call to complete
        await page.waitForResponse('**/api/v1/web/campaigns/1/start');
    });

    test('stop campaign functionality', async ({ page }) => {
        await page.route('**/api/v1/web/campaigns/1', async (route) => {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify(runningCampaign)
            });
        });

        await page.goto('/campaigns/1');

        // Click stop campaign
        await page.getByTestId('stop-campaign').click();

        // Wait for the API call to complete
        await page.waitForResponse('**/api/v1/web/campaigns/1/stop');
    });

    test('handles loading state', async ({ page }) => {
        // Mock a slow response
        await page.route('**/api/v1/web/campaigns/1', async (route) => {
            await new Promise((resolve) => setTimeout(resolve, 1000));
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify(mockCampaign)
            });
        });

        await page.goto('/campaigns/1');

        // Should show loading state initially
        await expect(page.getByTestId('loading')).toBeVisible();
        await expect(page.getByTestId('loading')).toHaveText('Loading campaign details…');

        // Wait for content to load
        await expect(page.getByTestId('campaign-name')).toBeVisible();
        await expect(page.getByTestId('loading')).not.toBeVisible();
    });

    test('handles error state', async ({ page }) => {
        await page.route('**/api/v1/web/campaigns/1', async (route) => {
            await route.fulfill({
                status: 500,
                contentType: 'application/json',
                body: JSON.stringify({ error: 'Internal server error' })
            });
        });

        await page.goto('/campaigns/1');

        // Should show error message
        await expect(page.getByTestId('error')).toBeVisible();
        await expect(page.getByTestId('error')).toHaveText('Failed to load campaign details.');
    });

    test('handles not found state', async ({ page }) => {
        await page.route('**/api/v1/web/campaigns/999', async (route) => {
            await route.fulfill({
                status: 404,
                contentType: 'application/json',
                body: JSON.stringify({ error: 'Campaign not found' })
            });
        });

        await page.goto('/campaigns/999');

        // Should show not found message
        await expect(page.getByTestId('error')).toBeVisible();
        await expect(page.getByTestId('error')).toHaveText('Failed to load campaign details.');
    });

    test('back to campaigns navigation', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Click back to campaigns button
        await page.getByText('← Back to Campaigns').click();

        // Should navigate to campaigns list
        await expect(page).toHaveURL('/campaigns');
    });

    test('complexity visualization renders correctly', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Check complexity dots for first attack (score: 3)
        const firstComplexity = page.getByTestId('attack-row-1').locator('.flex.space-x-1').first();
        const dots = firstComplexity.locator('span');

        // Should have 5 dots total
        await expect(dots).toHaveCount(5);

        // First 3 should be filled (gray-600), last 2 should be empty (gray-200)
        for (let i = 0; i < 3; i++) {
            await expect(dots.nth(i)).toHaveClass(/bg-gray-600/);
        }
        for (let i = 3; i < 5; i++) {
            await expect(dots.nth(i)).toHaveClass(/bg-gray-200/);
        }
    });

    test('page title updates correctly', async ({ page }) => {
        await page.goto('/campaigns/1');

        await expect(page).toHaveTitle('Test Campaign - CipherSwarm');
    });

    test('attack badges display correct colors and labels', async ({ page }) => {
        await page.goto('/campaigns/1');

        // Check dictionary attack badge
        const dictionaryBadge = page.getByTestId('attack-row-1').locator('.bg-blue-500').first();
        await expect(dictionaryBadge).toContainText('Dictionary');

        // Check brute force attack badge
        const bruteForceBadge = page.getByTestId('attack-row-2').locator('.bg-orange-500').first();
        await expect(bruteForceBadge).toContainText('Brute Force');
    });
});
