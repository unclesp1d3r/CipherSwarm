import { test, expect } from '@playwright/test';

test.describe('Campaign Modals', () => {
	test.beforeEach(async ({ page }) => {
		// Mock all API calls with more specific patterns
		await page.route(/\/api\/v1\/web\/campaigns\?.*/, async (route) => {
			if (route.request().method() === 'GET') {
				await route.fulfill({
					status: 200,
					contentType: 'application/json',
					body: JSON.stringify({
						items: [],
						total: 0
					})
				});
			}
		});

		await page.route(/\/api\/v1\/web\/campaigns\/$/, async (route) => {
			if (route.request().method() === 'POST') {
				await route.fulfill({
					status: 201,
					contentType: 'application/json',
					body: JSON.stringify({
						id: 1,
						name: 'Test Campaign',
						description: 'Test Description',
						priority: 1,
						project_id: 1,
						hash_list_id: 1,
						is_unavailable: false,
						state: 'draft',
						created_at: new Date().toISOString(),
						updated_at: new Date().toISOString()
					})
				});
			}
		});

		await page.route(/\/api\/v1\/web\/campaigns\/\d+/, async (route) => {
			if (route.request().method() === 'PATCH') {
				await route.fulfill({
					status: 200,
					contentType: 'application/json',
					body: JSON.stringify({
						id: 1,
						name: 'Updated Campaign',
						description: 'Updated Description',
						priority: 2,
						project_id: 1,
						hash_list_id: 1,
						is_unavailable: true,
						state: 'draft',
						created_at: new Date().toISOString(),
						updated_at: new Date().toISOString()
					})
				});
			}

			if (route.request().method() === 'DELETE') {
				await route.fulfill({
					status: 204,
					contentType: 'application/json'
				});
			}
		});

		// Navigate to a test page that includes these modals
		await page.goto('/campaigns');
	});

	test.describe('Campaign Editor Modal', () => {
		test('creates a new campaign', async ({ page }) => {
			// Open the create campaign modal (assuming there's a button to trigger it)
			await page.click('[data-testid="create-campaign-button"]');

			// Wait for modal to open and verify it's visible
			await expect(page.locator('[data-testid="modal-title"]')).toBeVisible();
			await expect(page.locator('[data-testid="modal-title"]')).toHaveText('Create Campaign');

			// Fill out the form
			await page.fill('[data-testid="name-input"]', 'Test Campaign');
			await page.fill('[data-testid="description-input"]', 'Test Description');
			await page.fill('[data-testid="priority-input"]', '1');

			// Submit the form
			await page.click('[data-testid="submit-button"]');

			// Verify success (modal should close)
			await expect(page.locator('[data-testid="modal-title"]')).not.toBeVisible();
		});

		test('edits an existing campaign', async ({ page }) => {
			// Mock an existing campaign for editing - override the empty campaigns list
			await page.route(/\/api\/v1\/web\/campaigns\?.*/, async (route) => {
				if (route.request().method() === 'GET') {
					await route.fulfill({
						status: 200,
						contentType: 'application/json',
						body: JSON.stringify({
							items: [
								{
									id: 1,
									name: 'Existing Campaign',
									description: 'Existing Description',
									priority: 1,
									project_id: 1,
									hash_list_id: 1,
									is_unavailable: false,
									state: 'draft',
									progress: 50,
									summary: '1 attack / 0 running / ETA 2h',
									attacks: [],
									created_at: new Date().toISOString(),
									updated_at: new Date().toISOString()
								}
							],
							total: 1
						})
					});
				}
			});

			// Reload the page to show the campaign
			await page.reload();

			// Click the campaign menu button
			await page.click('[data-testid="campaign-menu-1"]');

			// Click edit from the dropdown
			await page.click('text=Edit Campaign');

			// Verify modal is in edit mode
			await expect(page.locator('[data-testid="modal-title"]')).toHaveText('Edit Campaign');
			await expect(page.locator('[data-testid="name-input"]')).toHaveValue(
				'Existing Campaign'
			);

			// Update the campaign
			await page.fill('[data-testid="name-input"]', 'Updated Campaign');
			await page.fill('[data-testid="description-input"]', 'Updated Description');
			await page.fill('[data-testid="priority-input"]', '2');
			await page.check('[data-testid="unavailable-checkbox"]');

			// Submit the form
			await page.click('[data-testid="submit-button"]');

			// Verify success
			await expect(page.locator('[data-testid="modal-title"]')).not.toBeVisible();
		});

		test('shows validation errors', async ({ page }) => {
			// Mock validation error response
			await page.route(/\/api\/v1\/web\/campaigns\/$/, async (route) => {
				if (route.request().method() === 'POST') {
					await route.fulfill({
						status: 422,
						contentType: 'application/json',
						body: JSON.stringify({
							detail: [
								{
									loc: ['name'],
									msg: 'Name is required',
									type: 'value_error'
								}
							]
						})
					});
				}
			});

			// Open the create modal
			await page.click('[data-testid="create-campaign-button"]');

			// Remove the required attribute to allow form submission without validation
			await page.evaluate(() => {
				const nameInput = document.querySelector(
					'[data-testid="name-input"]'
				) as HTMLInputElement;
				if (nameInput) {
					nameInput.removeAttribute('required');
				}
			});

			// Submit without filling required fields
			await page.click('[data-testid="submit-button"]');

			// Verify validation error is shown
			await expect(page.locator('[data-testid="name-error"]')).toHaveText('Name is required');
		});

		test('shows loading state during submission', async ({ page }) => {
			// Mock delayed response
			await page.route(/\/api\/v1\/web\/campaigns\/$/, async (route) => {
				if (route.request().method() === 'POST') {
					// Delay response to test loading state
					await new Promise((resolve) => setTimeout(resolve, 1000));
					await route.fulfill({
						status: 201,
						contentType: 'application/json',
						body: JSON.stringify({
							id: 1,
							name: 'Test Campaign',
							description: 'Test Description',
							priority: 1,
							project_id: 1,
							hash_list_id: 1,
							is_unavailable: false
						})
					});
				}
			});

			// Open modal and fill form
			await page.click('[data-testid="create-campaign-button"]');
			await page.fill('[data-testid="name-input"]', 'Test Campaign');

			// Submit and check loading state
			await page.click('[data-testid="submit-button"]');
			await expect(page.locator('[data-testid="submit-button"]')).toHaveText('Saving...');
			await expect(page.locator('[data-testid="submit-button"]')).toBeDisabled();
		});

		test('cancels and closes modal', async ({ page }) => {
			// Open modal
			await page.click('[data-testid="create-campaign-button"]');
			await expect(page.locator('[data-testid="modal-title"]')).toBeVisible();

			// Cancel
			await page.click('[data-testid="cancel-button"]');
			await expect(page.locator('[data-testid="modal-title"]')).not.toBeVisible();
		});
	});

	test.describe('Campaign Delete Modal', () => {
		test.beforeEach(async ({ page }) => {
			// Mock a campaign to delete - override the empty campaigns list
			await page.route(/\/api\/v1\/web\/campaigns\?.*/, async (route) => {
				if (route.request().method() === 'GET') {
					await route.fulfill({
						status: 200,
						contentType: 'application/json',
						body: JSON.stringify({
							items: [
								{
									id: 1,
									name: 'Test Campaign',
									description: 'Test Description',
									priority: 1,
									project_id: 1,
									hash_list_id: 1,
									is_unavailable: false,
									state: 'draft',
									progress: 25,
									summary: '0 attacks / 0 running',
									attacks: [],
									created_at: new Date().toISOString(),
									updated_at: new Date().toISOString()
								}
							],
							total: 1
						})
					});
				}
			});

			// Reload the page to show the campaign
			await page.reload();
		});

		test('deletes a campaign successfully', async ({ page }) => {
			// Click the campaign menu button
			await page.click('[data-testid="campaign-menu-1"]');

			// Click delete from the dropdown
			await page.click('text=Delete Campaign');

			// Verify modal content
			await expect(page.locator('[data-testid="modal-title"]')).toHaveText('Delete Campaign');
			await expect(page.locator('[data-testid="campaign-name"]')).toHaveText('Test Campaign');
			await expect(page.locator('[data-testid="campaign-description"]')).toHaveText(
				'Test Description'
			);

			// Confirm deletion
			await page.click('[data-testid="delete-button"]');

			// Verify success
			await expect(page.locator('[data-testid="modal-title"]')).not.toBeVisible();
		});

		test('shows warning for running campaigns', async ({ page }) => {
			// Override the mock to return a running campaign
			await page.route(/\/api\/v1\/web\/campaigns\?.*/, async (route) => {
				if (route.request().method() === 'GET') {
					await route.fulfill({
						status: 200,
						contentType: 'application/json',
						body: JSON.stringify({
							items: [
								{
									id: 1,
									name: 'Running Campaign',
									description: 'This campaign is currently running',
									priority: 1,
									project_id: 1,
									hash_list_id: 1,
									is_unavailable: false,
									state: 'running',
									progress: 75,
									summary: '2 attacks / 1 running',
									attacks: [],
									created_at: new Date().toISOString(),
									updated_at: new Date().toISOString()
								}
							],
							total: 1
						})
					});
				}
			});

			await page.reload();

			// Click the campaign menu button
			await page.click('[data-testid="campaign-menu-1"]');

			// Click delete from the dropdown
			await page.click('text=Delete Campaign');

			await expect(page.locator('[data-testid="running-warning"]')).toBeVisible();
			await expect(page.locator('[data-testid="running-warning"]')).toContainText(
				'Warning: This campaign is currently running'
			);
		});

		test('handles delete errors', async ({ page }) => {
			// Mock error response
			await page.route(/\/api\/v1\/web\/campaigns\/\d+/, async (route) => {
				if (route.request().method() === 'DELETE') {
					await route.fulfill({
						status: 500,
						contentType: 'application/json',
						body: JSON.stringify({ message: 'Internal server error' })
					});
				}
			});

			// Click the campaign menu button
			await page.click('[data-testid="campaign-menu-1"]');

			// Click delete from the dropdown
			await page.click('text=Delete Campaign');

			await page.click('[data-testid="delete-button"]');

			await expect(page.locator('[data-testid="error-message"]')).toHaveText(
				'Failed to delete campaign.'
			);
		});

		test('handles specific error codes', async ({ page }) => {
			const errorCases = [
				{ status: 404, expectedMessage: 'Campaign not found.' },
				{
					status: 403,
					expectedMessage: 'You do not have permission to delete this campaign.'
				},
				{
					status: 409,
					expectedMessage: 'Cannot delete campaign that is currently running.'
				}
			];

			for (const { status, expectedMessage } of errorCases) {
				// Mock specific error response
				await page.route(/\/api\/v1\/web\/campaigns\/\d+/, async (route) => {
					if (route.request().method() === 'DELETE') {
						await route.fulfill({
							status,
							contentType: 'application/json'
						});
					}
				});

				// Click the campaign menu button
				await page.click('[data-testid="campaign-menu-1"]');

				// Click delete from the dropdown
				await page.click('text=Delete Campaign');

				await page.click('[data-testid="delete-button"]');

				await expect(page.locator('[data-testid="error-message"]')).toHaveText(
					expectedMessage
				);

				// Close modal for next iteration
				await page.click('[data-testid="cancel-button"]');
			}
		});

		test('shows loading state during deletion', async ({ page }) => {
			// Mock delayed response
			await page.route(/\/api\/v1\/web\/campaigns\/\d+/, async (route) => {
				if (route.request().method() === 'DELETE') {
					await new Promise((resolve) => setTimeout(resolve, 1000));
					await route.fulfill({
						status: 204,
						contentType: 'application/json'
					});
				}
			});

			// Click the campaign menu button
			await page.click('[data-testid="campaign-menu-1"]');

			// Click delete from the dropdown
			await page.click('text=Delete Campaign');

			await page.click('[data-testid="delete-button"]');

			await expect(page.locator('[data-testid="delete-button"]')).toHaveText('Deleting...');
			await expect(page.locator('[data-testid="delete-button"]')).toBeDisabled();
		});

		test('cancels and closes modal', async ({ page }) => {
			// Click the campaign menu button
			await page.click('[data-testid="campaign-menu-1"]');

			// Click delete from the dropdown
			await page.click('text=Delete Campaign');

			await expect(page.locator('[data-testid="modal-title"]')).toBeVisible();

			await page.click('[data-testid="cancel-button"]');
			await expect(page.locator('[data-testid="modal-title"]')).not.toBeVisible();
		});

		test('does not render when campaign is null', async ({ page }) => {
			// Override to return no campaigns (empty state)
			await page.route(/\/api\/v1\/web\/campaigns\?.*/, async (route) => {
				if (route.request().method() === 'GET') {
					await route.fulfill({
						status: 200,
						contentType: 'application/json',
						body: JSON.stringify({
							items: [],
							total: 0
						})
					});
				}
			});

			await page.reload();

			// Verify no campaign menu buttons exist (no campaigns to delete)
			await expect(page.locator('[data-testid^="campaign-menu-"]')).toHaveCount(0);

			// Verify modal is not visible
			await expect(page.locator('[data-testid="modal-title"]')).not.toBeVisible();
		});
	});
});
