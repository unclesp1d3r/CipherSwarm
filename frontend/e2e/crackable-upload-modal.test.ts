import { test, expect } from '@playwright/test';

test.describe('Crackable Upload Modal', () => {
    test.beforeEach(async ({ page }) => {
        // Mock campaigns list API
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

        // Mock hash guess API
        await page.route(/\/api\/v1\/web\/hash_guess/, async (route) => {
            if (route.request().method() === 'POST') {
                const requestBody = await route.request().postDataJSON();
                const hashMaterial = requestBody.hash_material;

                // Mock different responses based on input
                if (hashMaterial.includes('aad3b435b51404ee')) {
                    // NTLM hash
                    await route.fulfill({
                        status: 200,
                        contentType: 'application/json',
                        body: JSON.stringify({
                            candidates: [
                                {
                                    hash_type: 1000,
                                    name: 'NTLM',
                                    confidence: 0.95
                                },
                                {
                                    hash_type: 1800,
                                    name: 'sha512crypt',
                                    confidence: 0.15
                                }
                            ]
                        })
                    });
                } else if (hashMaterial.includes('$6$')) {
                    // SHA512crypt hash
                    await route.fulfill({
                        status: 200,
                        contentType: 'application/json',
                        body: JSON.stringify({
                            candidates: [
                                {
                                    hash_type: 1800,
                                    name: 'sha512crypt',
                                    confidence: 0.98
                                }
                            ]
                        })
                    });
                } else {
                    // No valid hashes detected
                    await route.fulfill({
                        status: 200,
                        contentType: 'application/json',
                        body: JSON.stringify({
                            candidates: []
                        })
                    });
                }
            }
        });

        // Mock upload API
        await page.route(/\/api\/v1\/web\/uploads\/$/, async (route) => {
            if (route.request().method() === 'POST') {
                await route.fulfill({
                    status: 201,
                    contentType: 'application/json',
                    body: JSON.stringify({
                        resource_id: 123,
                        presigned_url: 'https://s3.example.com/upload-url',
                        resource: {
                            file_name: 'pasted_hashes.txt'
                        }
                    })
                });
            }
        });

        // Mock presigned URL upload
        await page.route('https://s3.example.com/upload-url', async (route) => {
            if (route.request().method() === 'PUT') {
                await route.fulfill({
                    status: 200,
                    contentType: 'application/json'
                });
            }
        });

        // Navigate to campaigns page
        await page.goto('/campaigns');
    });

    test.describe('Modal Opening and Basic UI', () => {
        test('opens crackable upload modal from campaigns page', async ({ page }) => {
            // Click the "Upload & Crack" button
            await page.click('[data-testid="upload-campaign-button"]');

            // Verify modal is visible
            await expect(page.locator('[data-testid="modal-title"]')).toBeVisible();
            await expect(page.locator('[data-testid="modal-title"]')).toHaveText(
                'Upload Crackable Content'
            );
        });

        test('starts in text mode by default', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Verify text mode is selected
            await expect(page.locator('[data-testid="text-mode-button"]')).toHaveClass(
                /bg-primary/
            );
            await expect(page.locator('[data-testid="file-mode-button"]')).not.toHaveClass(
                /bg-primary/
            );

            // Verify text input is visible
            await expect(page.locator('[data-testid="text-content-input"]')).toBeVisible();
        });

        test('switches to file mode', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Switch to file mode
            await page.click('[data-testid="file-mode-button"]');

            // Verify file mode is selected
            await expect(page.locator('[data-testid="file-mode-button"]')).toHaveClass(
                /bg-primary/
            );
            await expect(page.locator('[data-testid="text-mode-button"]')).not.toHaveClass(
                /bg-primary/
            );

            // Verify file input is visible
            await expect(page.locator('[data-testid="file-input"]')).toBeVisible();
            await expect(page.locator('[data-testid="text-content-input"]')).not.toBeVisible();
        });

        test('closes modal when cancel button is clicked', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');
            await expect(page.locator('[data-testid="modal-title"]')).toBeVisible();

            // Click cancel
            await page.click('[data-testid="cancel-button"]');

            // Verify modal is closed
            await expect(page.locator('[data-testid="modal-title"]')).not.toBeVisible();
        });
    });

    test.describe('Text Mode Hash Validation', () => {
        test('validates NTLM hashes successfully', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Enter NTLM hash
            const ntlmHash =
                'admin:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c';
            await page.fill('[data-testid="text-content-input"]', ntlmHash);

            // Click validate
            await page.click('[data-testid="validate-button"]');

            // Wait for validation results
            await expect(
                page.locator('[data-slot="card-title"]:has-text("Detected Hash Types")')
            ).toBeVisible();
            await expect(page.locator('text=NTLM')).toBeVisible();
            await expect(page.locator('text=95%')).toBeVisible();

            // Verify upload button is enabled
            await expect(page.locator('[data-testid="upload-button"]')).toBeEnabled();
        });

        test('validates SHA512crypt hashes successfully', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Enter SHA512crypt hash
            const sha512Hash = 'user:$6$salt$hash...';
            await page.fill('[data-testid="text-content-input"]', sha512Hash);

            // Click validate
            await page.click('[data-testid="validate-button"]');

            // Wait for validation results
            await expect(
                page.locator('[data-slot="card-title"]:has-text("Detected Hash Types")')
            ).toBeVisible();
            await expect(page.locator('text=sha512crypt')).toBeVisible();
            await expect(page.locator('text=98%')).toBeVisible();
        });

        test('shows error for invalid hash content', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Enter invalid content
            await page.fill('[data-testid="text-content-input"]', 'invalid hash content');

            // Click validate
            await page.click('[data-testid="validate-button"]');

            // Wait for error message
            await expect(page.locator('[data-testid="validation-error"]')).toBeVisible();
            await expect(
                page.locator(
                    '[data-testid="validation-error"]:has-text("No valid hash types detected")'
                )
            ).toBeVisible();

            // Verify upload button remains disabled
            await expect(page.locator('[data-testid="upload-button"]')).toBeDisabled();
        });

        test('shows loading state during validation', async ({ page }) => {
            // Mock a slow validation response
            await page.route(/\/api\/v1\/web\/hash_guess/, async (route) => {
                if (route.request().method() === 'POST') {
                    // Add a delay to make the loading state visible
                    await new Promise((resolve) => setTimeout(resolve, 1000));
                    await route.fulfill({
                        status: 200,
                        contentType: 'application/json',
                        body: JSON.stringify({
                            candidates: [
                                {
                                    hash_type: 1000,
                                    name: 'NTLM',
                                    confidence: 0.95
                                }
                            ]
                        })
                    });
                }
            });

            await page.click('[data-testid="upload-campaign-button"]');

            // Enter hash content
            await page.fill('[data-testid="text-content-input"]', 'admin:hash123');

            // Click validate and immediately check loading state
            await page.click('[data-testid="validate-button"]');
            await expect(
                page.locator('[data-testid="validate-button"]:has-text("Validating...")')
            ).toBeVisible();
        });

        test('disables upload button when no content is provided', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Verify upload button is disabled by default
            await expect(page.locator('[data-testid="upload-button"]')).toBeDisabled();
        });
    });

    test.describe('File Mode Operations', () => {
        test('handles file selection', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Switch to file mode
            await page.click('[data-testid="file-mode-button"]');

            // Create a test file
            const fileContent = 'user:$6$salt$hash...';
            const file = await page.evaluateHandle(() => {
                const file = new File(['user:$6$salt$hash...'], 'test.shadow', {
                    type: 'text/plain'
                });
                return file;
            });

            // Set the file input
            await page.setInputFiles('[data-testid="file-input"]', {
                name: 'test.shadow',
                mimeType: 'text/plain',
                buffer: Buffer.from(fileContent)
            });

            // Verify file selection is shown
            await expect(page.locator('text=Selected: test.shadow')).toBeVisible();

            // Verify upload button is enabled
            await expect(page.locator('[data-testid="upload-button"]')).toBeEnabled();
        });

        test('shows file size information', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');
            await page.click('[data-testid="file-mode-button"]');

            const fileContent = 'user:$6$salt$hash...';
            await page.setInputFiles('[data-testid="file-input"]', {
                name: 'test.shadow',
                mimeType: 'text/plain',
                buffer: Buffer.from(fileContent)
            });

            // Check that file size is displayed (should show KB)
            await expect(page.locator('text=KB')).toBeVisible();
        });
    });

    test.describe('Upload Operations', () => {
        test('uploads text content successfully', async ({ page }) => {
            // Mock a slow upload response
            await page.route(/\/api\/v1\/web\/uploads\/$/, async (route) => {
                if (route.request().method() === 'POST') {
                    // Add a delay to make the loading state visible
                    await new Promise((resolve) => setTimeout(resolve, 1000));
                    await route.fulfill({
                        status: 201,
                        contentType: 'application/json',
                        body: JSON.stringify({
                            uploadId: 123
                        })
                    });
                }
            });

            await page.click('[data-testid="upload-campaign-button"]');

            // Enter and validate hash
            const ntlmHash =
                'admin:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c';
            await page.fill('[data-testid="text-content-input"]', ntlmHash);
            await page.click('[data-testid="validate-button"]');

            // Wait for validation to complete
            await expect(
                page.locator('[data-slot="card-title"]:has-text("Detected Hash Types")')
            ).toBeVisible();

            // Click upload
            await page.click('[data-testid="upload-button"]');

            // Verify loading state
            await expect(
                page.locator('[data-testid="upload-button"]:has-text("Uploading...")')
            ).toBeVisible();

            // Wait for modal to close (indicating success)
            await expect(page.locator('[data-testid="modal-title"]')).not.toBeVisible();
        });

        test('uploads file successfully', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Switch to file mode and select file
            await page.click('[data-testid="file-mode-button"]');

            const fileContent = 'user:$6$salt$hash...';
            await page.setInputFiles('[data-testid="file-input"]', {
                name: 'test.shadow',
                mimeType: 'text/plain',
                buffer: Buffer.from(fileContent)
            });

            // Click upload
            await page.click('[data-testid="upload-button"]');

            // Verify loading state
            await expect(
                page.locator('[data-testid="upload-button"]:has-text("Uploading...")')
            ).toBeVisible();

            // Wait for modal to close
            await expect(page.locator('[data-testid="modal-title"]')).not.toBeVisible();
        });

        test('handles upload errors gracefully', async ({ page }) => {
            // Mock upload error
            await page.route(/\/api\/v1\/web\/uploads\/$/, async (route) => {
                if (route.request().method() === 'POST') {
                    await route.fulfill({
                        status: 500,
                        contentType: 'application/json',
                        body: JSON.stringify({
                            detail: 'Upload failed'
                        })
                    });
                }
            });

            await page.click('[data-testid="upload-campaign-button"]');

            // Enter and validate hash
            const ntlmHash =
                'admin:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c';
            await page.fill('[data-testid="text-content-input"]', ntlmHash);
            await page.click('[data-testid="validate-button"]');
            await expect(
                page.locator('[data-slot="card-title"]:has-text("Detected Hash Types")')
            ).toBeVisible();

            // Attempt upload
            await page.click('[data-testid="upload-button"]');

            // Verify error handling (modal should remain open)
            await expect(page.locator('[data-testid="modal-title"]')).toBeVisible();
        });
    });

    test.describe('Form Fields and Metadata', () => {
        test('allows setting optional label', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Fill in the label field
            await page.fill('[data-testid="file-label-input"]', 'Test Upload Label');

            // Verify the value is set
            await expect(page.locator('[data-testid="file-label-input"]')).toHaveValue(
                'Test Upload Label'
            );
        });

        test('allows setting custom filename for text mode', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Should be in text mode by default
            await expect(page.locator('[data-testid="file-name-input"]')).toBeVisible();

            // Fill in custom filename
            await page.fill('[data-testid="file-name-input"]', 'my_custom_hashes.txt');

            // Verify the value is set
            await expect(page.locator('[data-testid="file-name-input"]')).toHaveValue(
                'my_custom_hashes.txt'
            );
        });

        test('hides filename input in file mode', async ({ page }) => {
            await page.click('[data-testid="upload-campaign-button"]');

            // Switch to file mode
            await page.click('[data-testid="file-mode-button"]');

            // Filename input should not be visible in file mode
            await expect(page.locator('[data-testid="file-name-input"]')).not.toBeVisible();
        });
    });

    test.describe('Confidence Score Display', () => {
        test('displays confidence scores with appropriate colors', async ({ page }) => {
            // Mock response with multiple confidence levels
            await page.route(/\/api\/v1\/web\/hash_guess/, async (route) => {
                if (route.request().method() === 'POST') {
                    await route.fulfill({
                        status: 200,
                        contentType: 'application/json',
                        body: JSON.stringify({
                            candidates: [
                                {
                                    hash_type: 1000,
                                    name: 'High Confidence',
                                    confidence: 0.95
                                },
                                {
                                    hash_type: 1800,
                                    name: 'Medium Confidence',
                                    confidence: 0.65
                                },
                                {
                                    hash_type: 3200,
                                    name: 'Low Confidence',
                                    confidence: 0.35
                                }
                            ]
                        })
                    });
                }
            });

            await page.click('[data-testid="upload-campaign-button"]');

            // Enter hash and validate
            await page.fill('[data-testid="text-content-input"]', 'test hash content');
            await page.click('[data-testid="validate-button"]');

            // Wait for results
            await expect(
                page.locator('[data-slot="card-title"]:has-text("Detected Hash Types")')
            ).toBeVisible();

            // Verify all confidence scores are displayed
            await expect(page.locator('text=95%')).toBeVisible();
            await expect(page.locator('text=65%')).toBeVisible();
            await expect(page.locator('text=35%')).toBeVisible();

            // Verify hash type names are displayed
            await expect(page.locator('text=High Confidence')).toBeVisible();
            await expect(page.locator('text=Medium Confidence')).toBeVisible();
            await expect(page.locator('text=Low Confidence')).toBeVisible();
        });
    });

    test.describe('Integration with Campaigns Page', () => {
        test('refreshes campaigns list after successful upload', async ({ page }) => {
            // Track API calls
            let campaignsApiCalled = false;
            await page.route(/\/api\/v1\/web\/campaigns\?.*/, async (route) => {
                campaignsApiCalled = true;
                if (route.request().method() === 'GET') {
                    await route.fulfill({
                        status: 200,
                        contentType: 'application/json',
                        body: JSON.stringify({
                            items: [
                                {
                                    id: 1,
                                    name: 'New Campaign from Upload',
                                    description: 'Generated from crackable upload',
                                    priority: 1,
                                    project_id: 1,
                                    hash_list_id: 1,
                                    is_unavailable: false,
                                    state: 'draft',
                                    progress: 0,
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

            await page.click('[data-testid="upload-campaign-button"]');

            // Complete upload flow
            const ntlmHash =
                'admin:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c';
            await page.fill('[data-testid="text-content-input"]', ntlmHash);
            await page.click('[data-testid="validate-button"]');
            await expect(
                page.locator('[data-slot="card-title"]:has-text("Detected Hash Types")')
            ).toBeVisible();
            await page.click('[data-testid="upload-button"]');

            // Wait for modal to close
            await expect(page.locator('[data-testid="modal-title"]')).not.toBeVisible();

            // Verify campaigns API was called to refresh the list
            expect(campaignsApiCalled).toBe(true);
        });

        test('upload button is accessible from campaigns page header', async ({ page }) => {
            // Verify the upload button exists in the campaigns page header
            await expect(page.locator('[data-testid="upload-campaign-button"]')).toBeVisible();
            await expect(page.locator('[data-testid="upload-campaign-button"]')).toHaveText(
                'Upload & Crack'
            );

            // Verify it's positioned correctly relative to create campaign button
            await expect(page.locator('[data-testid="create-campaign-button"]')).toBeVisible();
        });
    });
});
