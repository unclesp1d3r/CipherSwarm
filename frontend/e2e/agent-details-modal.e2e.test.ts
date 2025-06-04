import { test, expect } from '@playwright/test';

// This test relies on the frontend's mock data fallback for /agents (see AgentList.svelte)
// No backend is required; the UI will show mock agents like 'dev-agent-1' if the API is unavailable.

test.describe('AgentDetailsModal', () => {
    test('opens modal, displays fields, validates, and submits', async ({ page }) => {
        await page.goto('/agents');

        // Assert mock agent row is present
        await expect(page.getByText('dev-agent-1')).toBeVisible();

        // Click the first Agent Details button (cog icon)
        const detailsBtn = page.getByRole('button', { name: /Agent Details/i }).first();
        await detailsBtn.click();

        // Modal should appear
        await expect(page.getByRole('dialog')).toBeVisible();
        await expect(page.getByText(/Agent Details/i)).toBeVisible();

        // Fields should be present
        await expect(page.getByRole('checkbox', { name: 'GPU' })).toBeVisible();
        await expect(page.getByRole('checkbox', { name: 'CPU' })).toBeVisible();
        await expect(page.getByRole('spinbutton', { name: 'Update Interval (sec)' })).toBeVisible();

        // Change Update Interval to invalid value (0) and blur
        const intervalInput = page.getByRole('spinbutton', { name: 'Update Interval (sec)' });
        await intervalInput.fill('0');
        await intervalInput.blur();
        await expect(page.getByText('Must be at least 1 second')).toBeVisible();

        // Change Update Interval to valid value (60)
        await intervalInput.fill('60');
        await intervalInput.blur();
        await expect(page.getByText('Must be at least 1 second')).not.toBeVisible();

        // Toggle GPU and CPU switches
        const gpuSwitch = page.getByRole('checkbox', { name: 'GPU' });
        const cpuSwitch = page.getByRole('checkbox', { name: 'CPU' });
        await gpuSwitch.click();
        await cpuSwitch.click();

        // Submit the form
        const saveBtn = page.getByRole('button', { name: /Save/i });
        await saveBtn.click();
        // (No backend, so just check modal is still open and no validation error)
        await expect(page.getByRole('dialog')).toBeVisible();
        await expect(page.getByText('Must be at least 1 second')).not.toBeVisible();

        // Close the modal
        const closeBtn = page.getByRole('button', { name: /Close/i });
        await closeBtn.click();
        await expect(page.getByRole('dialog')).not.toBeVisible();
    });
}); 