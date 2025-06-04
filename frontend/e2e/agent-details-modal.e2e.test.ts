import { test, expect } from '@playwright/test';
import fs from 'fs';

// This test now mocks /api/v1/web/agents to ensure deterministic agent data

test.describe('AgentDetailsModal', () => {
    test('opens modal, displays fields, validates, and submits', async ({ page }) => {
        // Mock the /api/v1/web/agents endpoint
        await page.route('**/api/v1/web/agents*', async (route) => {
            await route.fulfill({
                status: 200,
                contentType: 'application/json',
                body: JSON.stringify({
                    items: [
                        {
                            id: 1,
                            host_name: 'dev-agent-1',
                            operating_system: 'linux',
                            state: 'active',
                            temperature: 55,
                            utilization: 0.85,
                            current_attempts_sec: 12000000,
                            avg_attempts_sec: 11000000,
                            current_job: 'Project Alpha / Campaign 1 / Attack 1'
                        },
                        {
                            id: 2,
                            host_name: 'dev-agent-2',
                            operating_system: 'windows',
                            state: 'offline',
                            temperature: null,
                            utilization: 0,
                            current_attempts_sec: 0,
                            avg_attempts_sec: 0,
                            current_job: 'Idle'
                        }
                    ],
                    total: 2
                })
            });
        });

        await page.goto('/agents');

        // Wait for the agent row to be visible
        const agentRow = page.getByText('dev-agent-1');
        await expect(agentRow).toBeVisible();

        // Wait for the Agent Details button to be visible and enabled
        const detailsBtn = page.getByRole('button', { name: /Agent Details/i }).first();
        await expect(detailsBtn).toBeVisible();
        await expect(detailsBtn).toBeEnabled();

        await detailsBtn.click();

        // Modal should appear
        await expect(page.getByRole('dialog')).toBeVisible();
        await expect(page.getByText(/Agent Details/i)).toBeVisible();

        // Fields should be present
        await expect(page.getByRole('switch', { name: /GPU/i })).toBeVisible();
        await expect(page.getByRole('switch', { name: /CPU/i })).toBeVisible();
        await expect(page.getByRole('spinbutton', { name: /Update Interval/i })).toBeVisible();

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
        const gpuSwitch = page.getByRole('switch', { name: 'GPU' });
        const cpuSwitch = page.getByRole('switch', { name: 'CPU' });
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