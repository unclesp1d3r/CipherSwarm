import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import axios from 'axios';
import CrackableUploadModal from './CrackableUploadModal.svelte';

// Mock axios
vi.mock('axios', () => ({
	default: {
		post: vi.fn(),
		put: vi.fn(),
		get: vi.fn()
	}
}));

const mockedAxios = axios as unknown as {
	post: ReturnType<typeof vi.fn>;
	put: ReturnType<typeof vi.fn>;
	get: ReturnType<typeof vi.fn>;
};

describe('CrackableUploadModal', () => {
	beforeEach(() => {
		vi.clearAllMocks();
	});

	it('renders the modal when open', () => {
		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		expect(screen.getByTestId('modal-title')).toBeInTheDocument();
		expect(screen.getByText('Upload Crackable Content')).toBeInTheDocument();
	});

	it('starts in text mode by default', () => {
		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		const textModeButton = screen.getByTestId('text-mode-button');
		const fileModeButton = screen.getByTestId('file-mode-button');

		expect(textModeButton).toHaveClass('bg-primary'); // Default variant styling
		expect(fileModeButton).not.toHaveClass('bg-primary');
	});

	it('switches between text and file modes', async () => {
		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		const fileModeButton = screen.getByTestId('file-mode-button');
		await fireEvent.click(fileModeButton);

		expect(screen.getByTestId('file-input')).toBeInTheDocument();
		expect(screen.queryByTestId('text-content-input')).not.toBeInTheDocument();
	});

	it('validates hashes when validate button is clicked', async () => {
		const mockHashGuessResponse = {
			data: {
				candidates: [
					{
						hash_type: 1000,
						name: 'NTLM',
						confidence: 0.95
					},
					{
						hash_type: 1800,
						name: 'sha512crypt',
						confidence: 0.85
					}
				]
			}
		};

		mockedAxios.post.mockResolvedValueOnce(mockHashGuessResponse);

		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		const textInput = screen.getByTestId('text-content-input');
		const validateButton = screen.getByTestId('validate-button');

		await fireEvent.input(textInput, {
			target: {
				value: 'admin:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c'
			}
		});

		await fireEvent.click(validateButton);

		await waitFor(() => {
			expect(mockedAxios.post).toHaveBeenCalledWith('/api/v1/web/hash_guess/', {
				hash_material:
					'admin:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c'
			});
		});

		await waitFor(() => {
			expect(screen.getByText('Detected Hash Types')).toBeInTheDocument();
			expect(screen.getByText('NTLM')).toBeInTheDocument();
			expect(screen.getByText('95%')).toBeInTheDocument();
		});
	});

	it('shows validation error when no hashes are detected', async () => {
		const mockHashGuessResponse = {
			data: {
				candidates: []
			}
		};

		mockedAxios.post.mockResolvedValueOnce(mockHashGuessResponse);

		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		const textInput = screen.getByTestId('text-content-input');
		const validateButton = screen.getByTestId('validate-button');

		await fireEvent.input(textInput, {
			target: { value: 'invalid hash content' }
		});

		await fireEvent.click(validateButton);

		await waitFor(() => {
			expect(screen.getByTestId('validation-error')).toBeInTheDocument();
			expect(
				screen.getByText('No valid hash types detected. Please check your input format.')
			).toBeInTheDocument();
		});
	});

	it('uploads text content and shows preview step', async () => {
		const mockHashGuessResponse = {
			data: {
				candidates: [
					{
						hash_type: 1000,
						name: 'NTLM',
						confidence: 0.95
					}
				]
			}
		};

		const mockUploadResponse = {
			data: {
				resource_id: 123,
				resource: {
					file_name: 'pasted_hashes.txt'
				}
			}
		};

		const mockStatusResponse = {
			data: {
				status: 'completed',
				hash_type: 'NTLM',
				hash_type_id: 1000,
				preview: ['aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c'],
				validation_state: 'valid',
				total_hashes_found: 1,
				total_hashes_parsed: 1,
				campaign_id: null,
				hash_list_id: null,
				overall_progress_percentage: 100,
				processing_steps: [
					{
						step_name: 'hash_extraction',
						status: 'completed',
						progress_percentage: 100
					}
				]
			}
		};

		mockedAxios.post
			.mockResolvedValueOnce(mockHashGuessResponse) // Hash guess
			.mockResolvedValueOnce(mockUploadResponse); // Upload
		mockedAxios.get.mockResolvedValueOnce(mockStatusResponse); // Status

		const component = render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		const textInput = screen.getByTestId('text-content-input');
		const validateButton = screen.getByTestId('validate-button');
		const uploadButton = screen.getByTestId('upload-button');

		// Add hash content and validate
		await fireEvent.input(textInput, {
			target: {
				value: 'admin:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c'
			}
		});

		await fireEvent.click(validateButton);

		await waitFor(() => {
			expect(screen.getByText('Detected Hash Types')).toBeInTheDocument();
		});

		// Upload and move to preview
		await fireEvent.click(uploadButton);

		await waitFor(() => {
			expect(screen.getByText('Preview & Launch Campaign')).toBeInTheDocument();
		});

		await waitFor(() => {
			expect(screen.getByText('Processing Status')).toBeInTheDocument();
			expect(screen.getByText('Detected Hash Type')).toBeInTheDocument();
			expect(screen.getByText('Hash Preview')).toBeInTheDocument();
			expect(screen.getByText('NTLM')).toBeInTheDocument();
		});
	});

	it('shows back button in preview step', async () => {
		const mockHashGuessResponse = {
			data: {
				candidates: [
					{
						hash_type: 1000,
						name: 'NTLM',
						confidence: 0.95
					}
				]
			}
		};

		const mockUploadResponse = {
			data: {
				resource_id: 123,
				resource: {
					file_name: 'pasted_hashes.txt'
				}
			}
		};

		const mockStatusResponse = {
			data: {
				status: 'completed',
				hash_type: 'NTLM',
				hash_type_id: 1000,
				preview: ['hash1'],
				validation_state: 'valid',
				total_hashes_found: 1,
				total_hashes_parsed: 1,
				campaign_id: null,
				hash_list_id: null,
				overall_progress_percentage: 100,
				processing_steps: []
			}
		};

		mockedAxios.post
			.mockResolvedValueOnce(mockHashGuessResponse)
			.mockResolvedValueOnce(mockUploadResponse);
		mockedAxios.get.mockResolvedValueOnce(mockStatusResponse);

		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		const textInput = screen.getByTestId('text-content-input');
		const validateButton = screen.getByTestId('validate-button');
		const uploadButton = screen.getByTestId('upload-button');

		// Navigate to preview
		await fireEvent.input(textInput, {
			target: { value: 'admin:hash' }
		});
		await fireEvent.click(validateButton);
		await waitFor(() => screen.getByText('Detected Hash Types'));
		await fireEvent.click(uploadButton);
		await waitFor(() => screen.getByText('Preview & Launch Campaign'));

		// Test back button
		const backButton = screen.getByTestId('back-button');
		await fireEvent.click(backButton);

		await waitFor(() => {
			expect(screen.getByText('Upload Crackable Content')).toBeInTheDocument();
		});
	});

	it('launches campaign from preview step', async () => {
		const mockHashGuessResponse = {
			data: {
				candidates: [
					{
						hash_type: 1000,
						name: 'NTLM',
						confidence: 0.95
					}
				]
			}
		};

		const mockUploadResponse = {
			data: {
				resource_id: 123,
				resource: {
					file_name: 'pasted_hashes.txt'
				}
			}
		};

		const mockStatusResponse = {
			data: {
				status: 'completed',
				hash_type: 'NTLM',
				hash_type_id: 1000,
				preview: ['hash1'],
				validation_state: 'valid',
				total_hashes_found: 1,
				total_hashes_parsed: 1,
				campaign_id: null,
				hash_list_id: null,
				overall_progress_percentage: 100,
				processing_steps: []
			}
		};

		const mockStatusWithCampaign = {
			data: {
				...mockStatusResponse.data,
				campaign_id: 456
			}
		};

		mockedAxios.post
			.mockResolvedValueOnce(mockHashGuessResponse)
			.mockResolvedValueOnce(mockUploadResponse);
		mockedAxios.get
			.mockResolvedValueOnce(mockStatusResponse) // Initial status
			.mockResolvedValueOnce(mockStatusWithCampaign); // Status with campaign

		let successEvent: { uploadId: number } | null = null;
		const mockSuccessHandler = vi.fn((event: { uploadId: number }) => {
			successEvent = event;
		});

		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1,
				onsuccess: mockSuccessHandler
			}
		});

		const textInput = screen.getByTestId('text-content-input');
		const validateButton = screen.getByTestId('validate-button');
		const uploadButton = screen.getByTestId('upload-button');

		// Navigate to preview
		await fireEvent.input(textInput, {
			target: { value: 'admin:hash' }
		});
		await fireEvent.click(validateButton);
		await waitFor(() => screen.getByText('Detected Hash Types'));
		await fireEvent.click(uploadButton);
		await waitFor(() => screen.getByText('Preview & Launch Campaign'));

		// Launch campaign
		const launchButton = screen.getByTestId('launch-campaign-button');
		await fireEvent.click(launchButton);

		await waitFor(() => {
			expect(screen.getByText('Creating Campaign')).toBeInTheDocument();
		});

		// Wait for success event
		await waitFor(() => {
			expect(successEvent).toBeTruthy();
			expect(successEvent?.uploadId).toBe(123);
		});
	});

	it('disables launch button when campaign cannot be launched', async () => {
		const mockHashGuessResponse = {
			data: {
				candidates: [
					{
						hash_type: 1000,
						name: 'NTLM',
						confidence: 0.95
					}
				]
			}
		};

		const mockUploadResponse = {
			data: {
				resource_id: 123,
				resource: {
					file_name: 'pasted_hashes.txt'
				}
			}
		};

		const mockStatusResponse = {
			data: {
				status: 'failed',
				hash_type: null,
				hash_type_id: null,
				preview: [],
				validation_state: 'invalid',
				total_hashes_found: 0,
				total_hashes_parsed: 0,
				campaign_id: null,
				hash_list_id: null,
				overall_progress_percentage: 0,
				processing_steps: []
			}
		};

		mockedAxios.post
			.mockResolvedValueOnce(mockHashGuessResponse)
			.mockResolvedValueOnce(mockUploadResponse);
		mockedAxios.get.mockResolvedValueOnce(mockStatusResponse);

		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		const textInput = screen.getByTestId('text-content-input');
		const validateButton = screen.getByTestId('validate-button');
		const uploadButton = screen.getByTestId('upload-button');

		// Navigate to preview
		await fireEvent.input(textInput, {
			target: { value: 'admin:hash' }
		});
		await fireEvent.click(validateButton);
		await waitFor(() => screen.getByText('Detected Hash Types'));
		await fireEvent.click(uploadButton);
		await waitFor(() => screen.getByText('Preview & Launch Campaign'));

		// Check launch button is disabled
		const launchButton = screen.getByTestId('launch-campaign-button');
		expect(launchButton).toBeDisabled();
		expect(screen.getByText('Campaign cannot be launched:')).toBeInTheDocument();
	});

	it('handles upload errors gracefully', async () => {
		const mockHashGuessResponse = {
			data: {
				candidates: [
					{
						hash_type: 1000,
						name: 'NTLM',
						confidence: 0.95
					}
				]
			}
		};

		mockedAxios.post
			.mockResolvedValueOnce(mockHashGuessResponse) // Hash guess
			.mockRejectedValueOnce(new Error('Upload failed')); // Upload error

		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		const textInput = screen.getByTestId('text-content-input');
		const validateButton = screen.getByTestId('validate-button');
		const uploadButton = screen.getByTestId('upload-button');

		// Add hash content and validate
		await fireEvent.input(textInput, {
			target: { value: 'admin:hash' }
		});
		await fireEvent.click(validateButton);
		await waitFor(() => screen.getByText('Detected Hash Types'));

		// Try to upload
		await fireEvent.click(uploadButton);

		await waitFor(() => {
			expect(screen.getByTestId('upload-error')).toBeInTheDocument();
			expect(screen.getByText('Upload failed. Please try again.')).toBeInTheDocument();
		});
	});

	it('handles status loading errors gracefully', async () => {
		const mockHashGuessResponse = {
			data: {
				candidates: [
					{
						hash_type: 1000,
						name: 'NTLM',
						confidence: 0.95
					}
				]
			}
		};

		const mockUploadResponse = {
			data: {
				resource_id: 123,
				resource: {
					file_name: 'pasted_hashes.txt'
				}
			}
		};

		mockedAxios.post
			.mockResolvedValueOnce(mockHashGuessResponse)
			.mockResolvedValueOnce(mockUploadResponse);
		mockedAxios.get.mockRejectedValueOnce(new Error('Status failed'));

		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		const textInput = screen.getByTestId('text-content-input');
		const validateButton = screen.getByTestId('validate-button');
		const uploadButton = screen.getByTestId('upload-button');

		// Navigate to preview
		await fireEvent.input(textInput, {
			target: { value: 'admin:hash' }
		});
		await fireEvent.click(validateButton);
		await waitFor(() => screen.getByText('Detected Hash Types'));
		await fireEvent.click(uploadButton);
		await waitFor(() => screen.getByText('Preview & Launch Campaign'));

		await waitFor(() => {
			expect(screen.getByTestId('status-error')).toBeInTheDocument();
			expect(
				screen.getByText('Failed to load upload status. Please try again.')
			).toBeInTheDocument();
		});
	});

	it('uploads file successfully and shows preview', async () => {
		const mockUploadResponse = {
			data: {
				resource_id: 123,
				presigned_url: 'https://example.com/upload',
				resource: {
					file_name: 'test.shadow'
				}
			}
		};

		const mockStatusResponse = {
			data: {
				status: 'completed',
				hash_type: 'sha512crypt',
				hash_type_id: 1800,
				preview: ['$6$salt$hash...'],
				validation_state: 'valid',
				total_hashes_found: 1,
				total_hashes_parsed: 1,
				campaign_id: null,
				hash_list_id: null,
				overall_progress_percentage: 100,
				processing_steps: []
			}
		};

		mockedAxios.post.mockResolvedValueOnce(mockUploadResponse);
		mockedAxios.put.mockResolvedValueOnce({}); // Presigned URL upload
		mockedAxios.get.mockResolvedValueOnce(mockStatusResponse);

		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		// Switch to file mode
		const fileModeButton = screen.getByTestId('file-mode-button');
		await fireEvent.click(fileModeButton);

		// Select file
		const fileInput = screen.getByTestId('file-input');
		const file = new File(['test content'], 'test.shadow', { type: 'text/plain' });
		await fireEvent.change(fileInput, { target: { files: [file] } });

		// Upload
		const uploadButton = screen.getByTestId('upload-button');
		await fireEvent.click(uploadButton);

		await waitFor(() => {
			expect(screen.getByText('Preview & Launch Campaign')).toBeInTheDocument();
		});

		await waitFor(() => {
			expect(screen.getByText('sha512crypt')).toBeInTheDocument();
			expect(screen.getByText('$6$salt$hash...')).toBeInTheDocument();
		});

		// Verify presigned URL upload was called
		expect(mockedAxios.put).toHaveBeenCalledWith('https://example.com/upload', file, {
			headers: {
				'Content-Type': 'text/plain'
			}
		});
	});

	it('shows processing steps in preview', async () => {
		const mockHashGuessResponse = {
			data: {
				candidates: [
					{
						hash_type: 1000,
						name: 'NTLM',
						confidence: 0.95
					}
				]
			}
		};

		const mockUploadResponse = {
			data: {
				resource_id: 123,
				resource: {
					file_name: 'pasted_hashes.txt'
				}
			}
		};

		const mockStatusResponse = {
			data: {
				status: 'completed',
				hash_type: 'NTLM',
				hash_type_id: 1000,
				preview: ['hash1'],
				validation_state: 'valid',
				total_hashes_found: 1,
				total_hashes_parsed: 1,
				campaign_id: null,
				hash_list_id: null,
				overall_progress_percentage: 100,
				processing_steps: [
					{
						step_name: 'hash_extraction',
						status: 'completed',
						progress_percentage: 100
					},
					{
						step_name: 'validation',
						status: 'completed',
						progress_percentage: 100
					}
				]
			}
		};

		mockedAxios.post
			.mockResolvedValueOnce(mockHashGuessResponse)
			.mockResolvedValueOnce(mockUploadResponse);
		mockedAxios.get.mockResolvedValueOnce(mockStatusResponse);

		render(CrackableUploadModal, {
			props: {
				open: true,
				projectId: 1
			}
		});

		const textInput = screen.getByTestId('text-content-input');
		const validateButton = screen.getByTestId('validate-button');
		const uploadButton = screen.getByTestId('upload-button');

		// Navigate to preview
		await fireEvent.input(textInput, {
			target: { value: 'admin:hash' }
		});
		await fireEvent.click(validateButton);
		await waitFor(() => screen.getByText('Detected Hash Types'));
		await fireEvent.click(uploadButton);
		await waitFor(() => screen.getByText('Preview & Launch Campaign'));

		// Check processing steps are shown
		await waitFor(() => {
			expect(screen.getByText('Processing Steps')).toBeInTheDocument();
			expect(screen.getByText('Hash extraction')).toBeInTheDocument();
			expect(screen.getByText('Validation')).toBeInTheDocument();
		});
	});
});
