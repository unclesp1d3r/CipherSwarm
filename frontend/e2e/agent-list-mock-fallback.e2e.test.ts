import { test, expect } from '@playwright/test';

test.describe('AgentList (mocked API fallback)', () => {
	test('renders mock agent data when API is mocked', async ({ page }) => {
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
							temperature: 42,
							utilization: 0.8,
							current_attempts_sec: 1000,
							avg_attempts_sec: 900,
							current_job: 'hashcat -a 0 ...'
						},
						{
							id: 2,
							host_name: 'dev-agent-2',
							operating_system: 'windows',
							state: 'offline',
							temperature: null,
							utilization: null,
							current_attempts_sec: 0,
							avg_attempts_sec: 0,
							current_job: null
						}
					],
					total: 2
				})
			});
		});

		await page.goto('/agents');

		await expect(page.getByText('dev-agent-1')).toBeVisible();
		await expect(page.getByText('dev-agent-2')).toBeVisible();
		await expect(page.getByRole('heading', { name: 'Agents' })).toBeVisible();
		await expect(page.getByText('Status')).toBeVisible();
	});
});
