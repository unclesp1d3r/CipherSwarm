import { test, expect } from '@playwright/test';

test.describe('Campaign Progress and Metrics Components', () => {
	const mockCampaign = {
		id: 1,
		name: 'Test Campaign',
		description: 'Test campaign description',
		state: 'running',
		progress: 45.5,
		attacks: [
			{
				id: 1,
				type: 'dictionary',
				language: 'en',
				length_min: 8,
				length_max: 12,
				settings_summary: 'Dictionary attack with common passwords',
				keyspace: 1000000,
				complexity_score: 3,
				position: 1,
				comment: 'Test attack',
				state: 'running'
			}
		],
		created_at: '2024-01-01T00:00:00Z',
		updated_at: '2024-01-01T12:00:00Z'
	};

	const mockProgress = {
		total_tasks: 100,
		active_agents: 3,
		completed_tasks: 45,
		pending_tasks: 30,
		active_tasks: 20,
		failed_tasks: 5,
		percentage_complete: 45.5,
		overall_status: 'running',
		active_attack_id: 1
	};

	const mockMetrics = {
		total_hashes: 50000,
		cracked_hashes: 12500,
		uncracked_hashes: 37500,
		percent_cracked: 25.0,
		progress_percent: 45.5
	};

	test.beforeEach(async ({ page }) => {
		// Mock the campaign detail API
		await page.route('/api/v1/web/campaigns/1', async (route) => {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(mockCampaign)
			});
		});

		// Mock the progress API
		await page.route('/api/v1/web/campaigns/1/progress', async (route) => {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(mockProgress)
			});
		});

		// Mock the metrics API
		await page.route('/api/v1/web/campaigns/1/metrics', async (route) => {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(mockMetrics)
			});
		});

		await page.goto('/campaigns/1');
	});

	test('displays campaign progress component correctly', async ({ page }) => {
		// Wait for the progress component to load
		await expect(page.getByTestId('campaign-progress-card')).toBeVisible();

		// Check progress card title
		await expect(
			page.getByTestId('campaign-progress-card').getByText('Campaign Progress')
		).toBeVisible();

		// Check progress percentage
		await expect(page.getByTestId('progress-percentage')).toContainText('45.5%');

		// Check progress bar
		await expect(page.getByTestId('campaign-progress-bar')).toBeVisible();

		// Check status badge
		await expect(page.getByTestId('progress-status')).toContainText('Running');

		// Check active agents
		await expect(page.getByTestId('active-agents')).toContainText('3');

		// Check task breakdown
		await expect(page.getByTestId('total-tasks')).toContainText('100');
		await expect(page.getByTestId('completed-tasks')).toContainText('45');
		await expect(page.getByTestId('active-tasks')).toContainText('20');
		await expect(page.getByTestId('pending-tasks')).toContainText('30');
		await expect(page.getByTestId('failed-tasks')).toContainText('5');

		// Check active attack ID
		await expect(page.getByTestId('active-attack')).toContainText('#1');
	});

	test('displays campaign metrics component correctly', async ({ page }) => {
		// Wait for the metrics component to load
		await expect(page.getByTestId('campaign-metrics-card')).toBeVisible();

		// Check metrics card title
		await expect(page.getByText('Campaign Metrics')).toBeVisible();

		// Check hash statistics
		await expect(page.getByTestId('total-hashes')).toContainText('50,000');
		await expect(page.getByTestId('cracked-hashes')).toContainText('12,500');
		await expect(page.getByTestId('uncracked-hashes')).toContainText('37,500');

		// Check percentages
		await expect(page.getByTestId('percent-cracked')).toContainText('25.0%');
		await expect(page.getByTestId('progress-percent')).toContainText('45.5%');

		// Check progress bars
		await expect(page.getByTestId('campaign-cracking-progress-bar')).toBeVisible();
		await expect(page.getByTestId('campaign-overall-progress-bar')).toBeVisible();

		// Check cracking percentage display
		await expect(page.getByTestId('cracking-percentage')).toContainText('25.0%');
		await expect(page.getByTestId('overall-percentage')).toContainText('45.5%');

		// Check summary text
		await expect(page.getByTestId('metrics-summary')).toContainText(
			'12,500 of 50,000 hashes cracked (25.0%)'
		);
	});

	test('handles progress API error gracefully', async ({ page }) => {
		// Mock progress API error
		await page.route('/api/v1/web/campaigns/1/progress', async (route) => {
			await route.fulfill({
				status: 500,
				contentType: 'application/json',
				body: JSON.stringify({ detail: 'Internal server error' })
			});
		});

		await page.reload();

		// Check that error is displayed
		await expect(page.getByTestId('progress-error')).toContainText(
			'Failed to load campaign progress.'
		);
	});

	test('handles metrics API error gracefully', async ({ page }) => {
		// Mock metrics API error
		await page.route('/api/v1/web/campaigns/1/metrics', async (route) => {
			await route.fulfill({
				status: 500,
				contentType: 'application/json',
				body: JSON.stringify({ detail: 'Internal server error' })
			});
		});

		await page.reload();

		// Check that error is displayed
		await expect(page.getByTestId('metrics-error')).toContainText(
			'Failed to load campaign metrics.'
		);
	});

	test('displays loading states correctly', async ({ page }) => {
		// Mock delayed responses
		await page.route('/api/v1/web/campaigns/1/progress', async (route) => {
			await new Promise((resolve) => setTimeout(resolve, 1000));
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(mockProgress)
			});
		});

		await page.route('/api/v1/web/campaigns/1/metrics', async (route) => {
			await new Promise((resolve) => setTimeout(resolve, 1000));
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(mockMetrics)
			});
		});

		await page.reload();

		// Check loading states
		await expect(page.getByTestId('progress-loading')).toBeVisible();
		await expect(page.getByTestId('metrics-loading')).toBeVisible();

		// Wait for loading to complete
		await expect(page.getByTestId('progress-loading')).not.toBeVisible();
		await expect(page.getByTestId('metrics-loading')).not.toBeVisible();
	});

	test('handles different status badges correctly', async ({ page }) => {
		const statuses = [
			{ status: 'completed', label: 'Completed' },
			{ status: 'failed', label: 'Failed' },
			{ status: 'pending', label: 'Pending' },
			{ status: null, label: 'Unknown' }
		];

		for (const { status, label } of statuses) {
			const modifiedProgress = { ...mockProgress, overall_status: status };

			await page.route('/api/v1/web/campaigns/1/progress', async (route) => {
				await route.fulfill({
					status: 200,
					contentType: 'application/json',
					body: JSON.stringify(modifiedProgress)
				});
			});

			await page.reload();
			await expect(page.getByTestId('progress-status')).toContainText(label);
		}
	});

	test('handles zero hash metrics correctly', async ({ page }) => {
		const zeroMetrics = {
			total_hashes: 0,
			cracked_hashes: 0,
			uncracked_hashes: 0,
			percent_cracked: 0,
			progress_percent: 0
		};

		await page.route('/api/v1/web/campaigns/1/metrics', async (route) => {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(zeroMetrics)
			});
		});

		await page.reload();

		// Check that zero values are displayed correctly
		await expect(page.getByTestId('total-hashes')).toContainText('0');
		await expect(page.getByTestId('cracked-hashes')).toContainText('0');
		await expect(page.getByTestId('uncracked-hashes')).toContainText('0');
		await expect(page.getByTestId('percent-cracked')).toContainText('0.0%');

		// Summary should not be visible when total_hashes is 0
		await expect(page.getByTestId('metrics-summary')).not.toBeVisible();
	});

	test('handles missing active attack ID correctly', async ({ page }) => {
		const progressWithoutAttack = { ...mockProgress, active_attack_id: null };

		await page.route('/api/v1/web/campaigns/1/progress', async (route) => {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(progressWithoutAttack)
			});
		});

		await page.reload();

		// Active attack should not be visible when null
		await expect(page.getByTestId('active-attack')).not.toBeVisible();
	});

	test('components are responsive on mobile', async ({ page }) => {
		// Set mobile viewport
		await page.setViewportSize({ width: 375, height: 667 });

		await page.reload();

		// Check that components are still visible and functional on mobile
		await expect(page.getByTestId('campaign-progress-card')).toBeVisible();
		await expect(page.getByTestId('campaign-metrics-card')).toBeVisible();

		// Check that grid layout adapts (components should stack vertically)
		const progressBox = await page.getByTestId('campaign-progress-card').boundingBox();
		const metricsBox = await page.getByTestId('campaign-metrics-card').boundingBox();

		// On mobile, metrics should be below progress (higher y coordinate)
		expect(metricsBox!.y).toBeGreaterThan(progressBox!.y);
	});

	test('auto-refresh functionality works correctly', async ({ page }) => {
		let progressRequestCount = 0;

		// Count progress API requests - set up before reload
		await page.route('/api/v1/web/campaigns/1/progress', async (route) => {
			progressRequestCount++;
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(mockProgress)
			});
		});

		await page.route('/api/v1/web/campaigns/1/metrics', async (route) => {
			await route.fulfill({
				status: 200,
				contentType: 'application/json',
				body: JSON.stringify(mockMetrics)
			});
		});

		await page.reload();

		// Wait for initial load and first request
		await expect(page.getByTestId('campaign-progress-card')).toBeVisible();
		await expect(page.getByTestId('progress-percentage')).toContainText('45.5%');

		// Reset counter after initial load
		progressRequestCount = 0;

		// Wait for auto-refresh (components refresh every 5 seconds by default)
		await page.waitForTimeout(6000);

		// Should have made at least one refresh request
		expect(progressRequestCount).toBeGreaterThan(0);
	});
});
