import { test, expect } from '@playwright/test';
import fs from 'fs';

// This test now mocks /api/v1/web/agents to ensure deterministic agent data

// Generate a single set of timestamps for both GPUs
const timestamps = Array.from(
	{ length: 8 },
	(_, i) => new Date(Date.now() - (7 - i) * 60 * 60 * 1000)
); // oldest to newest

function generateLast8HoursDataForDevice(multiplier = 1) {
	return timestamps.map((ts) => ({
		timestamp: ts.toISOString(),
		speed: Math.random() * 100000000 * multiplier
	}));
}

test.describe('AgentDetailsModal', () => {
	test.beforeEach(async ({ page }) => {
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
							current_job: 'Project Alpha / Campaign 1 / Attack 1',
							custom_label: 'Agent One',
							last_seen_ip: '10.0.0.1',
							client_signature: 'sig-abc',
							token: 'tok-xyz',
							benchmarks_by_hash_type: {
								'1000': [
									{
										hash_type_id: '1000',
										hash_type_name: 'NTLM',
										hash_type_description: 'NT LAN Manager',
										hash_speed: 100000000,
										device: 'GPU0',
										runtime: 100,
										created_at: '2024-06-01T12:00:00Z'
									}
								]
							},
							performance_series: [
								{
									device: 'GPU0',
									data: generateLast8HoursDataForDevice(1)
								},
								{
									device: 'GPU1',
									data: generateLast8HoursDataForDevice(0.85)
								}
							],
							errors: [
								{
									created_at: '2024-06-01T12:00:00Z',
									severity: 'minor',
									message: 'Test error',
									task_id: 42,
									error_code: 'E001'
								}
							]
						}
					],
					total: 1
				})
			});
		});
		await page.goto('/agents');
		await expect(page.getByText('dev-agent-1')).toBeVisible();
		const detailsBtn = page.getByRole('button', { name: /Agent Details/i }).first();
		await expect(detailsBtn).toBeVisible();
		await expect(detailsBtn).toBeEnabled();
		await detailsBtn.click();
		await expect(page.getByRole('dialog')).toBeVisible();
		await expect(page.getByText(/Agent Details/i)).toBeVisible();
	});

	test('Settings tab displays and validates fields', async ({ page }) => {
		await expect(page.getByRole('tab', { name: /Settings/i })).toBeVisible();
		await expect(page.getByRole('tabpanel')).toContainText('Agent Label');
		await expect(page.getByRole('spinbutton', { name: /Update Interval/i })).toBeVisible();
		// Validation
		const intervalInput = page.getByRole('spinbutton', { name: /Update Interval/i });
		await intervalInput.fill('0');
		await intervalInput.blur();
		await expect(page.getByText('Must be at least 1 second')).toBeVisible();
		await intervalInput.fill('60');
		await intervalInput.blur();
		await expect(page.getByText('Must be at least 1 second')).not.toBeVisible();
		// Save
		const saveBtn = page.getByRole('button', { name: /Save/i });
		await saveBtn.click();
		await expect(page.getByRole('dialog')).toBeVisible();
	});

	test('Hardware tab displays device toggles', async ({ page }) => {
		await page.getByRole('tab', { name: /Hardware/i }).click();
		await expect(page.getByRole('tabpanel')).toContainText('Hardware Details');
		await expect(page.getByText('Platform Support')).toBeVisible();
	});

	test('Performance tab displays chart and device cards', async ({ page }) => {
		await page.getByRole('tab', { name: /Performance/i }).click();
		await expect(page.getByRole('tabpanel')).toContainText('Performance');
		// Assert the chart is rendered
		await expect(page.getByTestId('agent-performance-chart')).toBeVisible();
	});

	test('Log tab displays error log', async ({ page }) => {
		await page.getByRole('tab', { name: /Log/i }).click();
		await expect(page.getByRole('tabpanel')).toContainText('Error Log');
		await expect(page.getByText('Test error')).toBeVisible();
	});

	test('Capabilities tab displays benchmarks', async ({ page }) => {
		await page.getByRole('tab', { name: /Capabilities/i }).click();
		await expect(page.getByRole('tabpanel')).toContainText('Benchmark Summary');
		await expect(page.getByText('NTLM')).toBeVisible();
		await expect(page.getByText('View Devices')).toBeVisible();
	});
});
