import { test, expect } from '@playwright/test';

const dashboardSummary = {
	active_agents: 2,
	total_agents: 5,
	running_tasks: 3,
	total_tasks: 10,
	recently_cracked_hashes: 42,
	resource_usage: [
		{ timestamp: '2025-06-04T21:11:26.190Z', hash_rate: 100 },
		{ timestamp: '2025-06-04T22:11:26.190Z', hash_rate: 200 },
		{ timestamp: '2025-06-04T23:11:26.190Z', hash_rate: 150 }
	]
};

const campaigns = {
	items: [
		{
			name: 'Test Campaign',
			description: 'A test campaign',
			project_id: 1,
			priority: 1,
			hash_list_id: 1,
			is_unavailable: false,
			id: 123,
			state: 'running',
			created_at: '2025-06-04T21:11:26.185Z',
			updated_at: '2025-06-04T21:11:26.185Z'
		}
	],
	total: 1,
	page: 1,
	size: 10,
	total_pages: 1
};

test.describe('Dashboard Page', () => {
	test('renders dashboard metrics and campaign overview with mocked API', async ({ page }) => {
		await page.route('**/api/v1/web/dashboard/summary', async (route) => {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(dashboardSummary)
			});
		});
		await page.route('**/api/v1/web/campaigns', async (route) => {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(campaigns)
			});
		});

		await page.goto('/');

		// Active Agents card
		await expect(page.getByText('Active Agents')).toBeVisible();
		await expect(page.locator('.text-3xl.font-bold').first()).toHaveText('2');
		await expect(page.getByText('/ 5')).toBeVisible();

		// Running Tasks card
		const runningTasksCard = page.getByText('Running Tasks').locator('..').locator('..');
		await expect(runningTasksCard.getByText('Running Tasks')).toBeVisible();
		await expect(runningTasksCard.locator('.text-3xl.font-bold')).toHaveText('3');

		// Recently Cracked Hashes card
		const crackedHashesCard = page
			.getByText('Recently Cracked Hashes')
			.locator('..')
			.locator('..');
		await expect(crackedHashesCard.getByText('Recently Cracked Hashes')).toBeVisible();
		await expect(crackedHashesCard.locator('.text-3xl.font-bold')).toHaveText('42');

		// Resource Usage card
		const resourceUsageCard = page.getByText('Resource Usage').locator('..').locator('..');
		await expect(resourceUsageCard.getByText('Resource Usage')).toBeVisible();
		await expect(resourceUsageCard.getByText('Hashrate (8h)')).toBeVisible();

		// Campaign overview
		await expect(page.getByRole('heading', { name: 'Campaign Overview' })).toBeVisible();
		const campaignItem = page.getByText('Test Campaign').locator('..').locator('..');
		await expect(campaignItem.getByText('Test Campaign')).toBeVisible();
		await expect(campaignItem.getByText('active')).toBeVisible();

		// No loading or error
		await expect(page.getByText('Loading dashboard...')).not.toBeVisible();
		await expect(page.locator('.text-red-500')).toHaveCount(0);
	});
});
