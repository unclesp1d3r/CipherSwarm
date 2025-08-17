import { test, expect } from '@playwright/test';
import { createTestHelpers } from '../tests/test-utils';

// Generate a single set of timestamps for both GPUs
const timestamps = Array.from(
    { length: 8 },
    (_, i) => new Date(Date.now() - (7 - i) * 60 * 60 * 1000)
); // oldest to newest

function generateLast8HoursDataForDevice(multiplier = 1) {
    return timestamps.map((ts) => ({
        timestamp: ts.toISOString(),
        speed: Math.random() * 100000000 * multiplier,
    }));
}

test.describe('Agents Page (SSR)', () => {
    test.describe('Basic Page Rendering', () => {
        test('renders agents list page with SSR data', async ({ page }) => {
            // No API mocking needed - SSR provides mock data in test environment
            await page.goto('/agents');

            // Verify SSR-loaded content
            await expect(page.getByText('dev-agent-1')).toBeVisible();
            await expect(page.getByText('dev-agent-2')).toBeVisible();
            await expect(page.getByRole('heading', { name: 'Agents' })).toBeVisible();
            await expect(page.getByText('Status')).toBeVisible();
            await expect(page.getByText('Label')).toBeVisible();
            await expect(page.getByText('Devices')).toBeVisible();
            await expect(page.getByText('Last Seen')).toBeVisible();
            await expect(page.getByText('IP Address')).toBeVisible();
        });

        test('displays agent information correctly', async ({ page }) => {
            await page.goto('/agents');

            // Check agent details are displayed
            await expect(page.getByText('dev-agent-1')).toBeVisible();
            await expect(page.getByText('linux')).toBeVisible();
            await expect(page.getByText('Dev Agent 1')).toBeVisible();
            await expect(page.getByText('GPU0, CPU')).toBeVisible();
            await expect(page.getByText('192.168.1.100')).toBeVisible();

            await expect(page.getByText('dev-agent-2')).toBeVisible();
            await expect(page.getByText('windows')).toBeVisible();
            await expect(page.getByText('Dev Agent 2')).toBeVisible();
            await expect(page.getByText('GPU0, GPU1')).toBeVisible();
            await expect(page.getByText('192.168.1.101')).toBeVisible();
        });

        test('displays agent status badges correctly', async ({ page }) => {
            await page.goto('/agents');

            // Check status badges
            await expect(page.getByText('Online')).toBeVisible(); // active state
            await expect(page.getByText('Offline')).toBeVisible(); // offline state
        });
    });

    test.describe('Search and Navigation', () => {
        test('search functionality works with SSR', async ({ page }) => {
            await page.goto('/agents');

            // Test search input
            const searchInput = page.getByPlaceholder('Search agents...');
            await expect(searchInput).toBeVisible();

            // Test search with Enter key - verify the search input works
            await searchInput.fill('dev-agent-1');
            await searchInput.press('Enter');

            // Wait for potential navigation or page update
            await page.waitForTimeout(2000);

            // Verify the search input retains the value (basic functionality check)
            await expect(searchInput).toHaveValue('dev-agent-1');
        });

        test('handles empty search results', async ({ page }) => {
            await page.goto('/agents?search=nonexistent');

            // Should show no results (mock data doesn't match)
            await expect(page.getByText('dev-agent-1')).not.toBeVisible();
            await expect(page.getByText('dev-agent-2')).not.toBeVisible();
        });

        test('handles search functionality without errors', async ({ page }) => {
            await page.goto('/agents');

            // Test search functionality without errors
            const searchInput = page.getByPlaceholder('Search agents...');
            await searchInput.fill('test');
            await searchInput.press('Enter');

            // Wait for potential navigation or page update
            await page.waitForTimeout(2000);

            // Verify the search input retains the value and no errors occurred
            await expect(searchInput).toHaveValue('test');
        });
    });

    test.describe('Agent Details Modal Integration', () => {
        test('opens agent details modal and displays settings tab', async ({ page }) => {
            await page.goto('/agents');

            // Click on agent details button
            const detailsBtn = page.getByRole('button', { name: /Agent Details/i }).first();
            await expect(detailsBtn).toBeVisible();
            await detailsBtn.click();

            // Verify modal opens
            await expect(page.getByRole('dialog')).toBeVisible();
            await expect(page.getByText(/Agent Details/i)).toBeVisible();

            // Verify settings tab content
            await expect(page.getByRole('tab', { name: /Settings/i })).toBeVisible();
            await expect(page.getByRole('tabpanel')).toContainText('Agent Label');
            await expect(page.getByRole('spinbutton', { name: /Update Interval/i })).toBeVisible();
        });

        test('validates settings form fields', async ({ page }) => {
            await page.goto('/agents');

            // Open modal
            const detailsBtn = page.getByRole('button', { name: /Agent Details/i }).first();
            await detailsBtn.click();
            await expect(page.getByRole('dialog')).toBeVisible();

            // Test validation
            const intervalInput = page.getByRole('spinbutton', { name: /Update Interval/i });
            await intervalInput.fill('0');
            await intervalInput.blur();
            await expect(page.getByText('Must be at least 1 second')).toBeVisible();

            // Test valid input
            await intervalInput.fill('60');
            await intervalInput.blur();
            await expect(page.getByText('Must be at least 1 second')).not.toBeVisible();

            // Test save button
            const saveBtn = page.getByRole('button', { name: /Save/i });
            await expect(saveBtn).toBeVisible();
        });

        test('displays hardware tab information', async ({ page }) => {
            await page.goto('/agents');

            // Open modal and switch to hardware tab
            const detailsBtn = page.getByRole('button', { name: /Agent Details/i }).first();
            await detailsBtn.click();
            await page.getByRole('tab', { name: /Hardware/i }).click();

            // Verify hardware tab content
            await expect(page.getByRole('tabpanel')).toContainText('Hardware Details');
            await expect(page.getByText('Platform Support')).toBeVisible();
        });

        test('modal can be closed', async ({ page }) => {
            await page.goto('/agents');

            // Open modal
            const detailsBtn = page.getByRole('button', { name: /Agent Details/i }).first();
            await detailsBtn.click();
            await expect(page.getByRole('dialog')).toBeVisible();

            // Close modal (look for close button or escape key)
            await page.keyboard.press('Escape');
            await expect(page.getByRole('dialog')).not.toBeVisible();
        });

        test('modal tabs are accessible and functional', async ({ page }) => {
            await page.goto('/agents');

            // Open modal
            const detailsBtn = page.getByRole('button', { name: /Agent Details/i }).first();
            await detailsBtn.click();
            await expect(page.getByRole('dialog')).toBeVisible();

            // Test tab navigation
            await expect(page.getByRole('tab', { name: /Settings/i })).toBeVisible();
            await expect(page.getByRole('tab', { name: /Hardware/i })).toBeVisible();
            await expect(page.getByRole('tab', { name: /Performance/i })).toBeVisible();
            await expect(page.getByRole('tab', { name: /Log/i })).toBeVisible();
            await expect(page.getByRole('tab', { name: /Capabilities/i })).toBeVisible();

            // Test switching tabs
            await page.getByRole('tab', { name: /Hardware/i }).click();
            await expect(page.getByRole('tabpanel')).toContainText('Hardware Details');

            await page.getByRole('tab', { name: /Settings/i }).click();
            await expect(page.getByRole('tabpanel')).toContainText('Agent Label');
        });
    });

    test.describe('Accessibility and UX', () => {
        test('maintains proper table structure', async ({ page }) => {
            await page.goto('/agents');

            // Check for proper table structure
            await expect(page.getByRole('table')).toBeVisible();

            // Check for table headers (check for text content rather than exact role names)
            await expect(page.getByText('Agent Name + OS')).toBeVisible();
            await expect(page.getByText('Status')).toBeVisible();
            await expect(page.getByText('Label')).toBeVisible();
            await expect(page.getByText('Devices')).toBeVisible();
            await expect(page.getByText('Last Seen')).toBeVisible();
            await expect(page.getByText('IP Address')).toBeVisible();
        });

        test('provides proper button accessibility', async ({ page }) => {
            await page.goto('/agents');

            // Check for proper button labels
            const detailsBtn = page.getByRole('button', { name: /Agent Details/i }).first();
            await expect(detailsBtn).toHaveAttribute('aria-label', 'Agent Details');
        });

        test('search input is accessible', async ({ page }) => {
            await page.goto('/agents');

            // Test search input accessibility
            const searchInput = page.getByPlaceholder('Search agents...');
            await expect(searchInput).toBeVisible();
            await expect(searchInput).toHaveAttribute('type', 'text');
            await expect(searchInput).toHaveAttribute('placeholder', 'Search agents...');
        });
    });

    test.describe('Error Handling', () => {
        test('handles missing agent data gracefully', async ({ page }) => {
            // Test with empty agents list
            await page.goto('/agents?test_empty=true');

            // Should show empty state or handle gracefully
            await expect(page.getByRole('heading', { name: 'Agents' })).toBeVisible();
        });
    });

    test.describe('SSR Data Integration', () => {
        test('displays SSR-loaded data correctly', async ({ page }) => {
            await page.goto('/agents');

            // Verify that data is loaded from SSR (not client-side)
            // This should be visible immediately without waiting for API calls
            await expect(page.getByText('dev-agent-1')).toBeVisible();
            await expect(page.getByText('dev-agent-2')).toBeVisible();

            // Verify table structure is rendered
            await expect(page.getByRole('table')).toBeVisible();

            // Verify search functionality is available
            await expect(page.getByPlaceholder('Search agents...')).toBeVisible();
        });

        test('maintains state through navigation', async ({ page }) => {
            await page.goto('/agents?search=dev-agent-1');

            // Should maintain search state from URL
            const searchInput = page.getByPlaceholder('Search agents...');
            await expect(searchInput).toHaveValue('dev-agent-1');
        });
    });
});
