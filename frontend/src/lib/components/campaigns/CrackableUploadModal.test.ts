import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/svelte';
import axios from 'axios';
import CrackableUploadModal from './CrackableUploadModal.svelte';

// Mock axios
vi.mock('axios', () => ({
    default: {
        post: vi.fn(),
        put: vi.fn()
    }
}));

const mockedAxios = axios as unknown as {
    post: ReturnType<typeof vi.fn>;
    put: ReturnType<typeof vi.fn>;
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
            expect(mockedAxios.post).toHaveBeenCalledWith('/api/v1/web/hash_guess', {
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

    it('uploads text content successfully', async () => {
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
            .mockResolvedValueOnce(mockHashGuessResponse) // Hash guess
            .mockResolvedValueOnce(mockUploadResponse); // Upload

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

        // Upload
        await fireEvent.click(uploadButton);

        await waitFor(() => {
            expect(mockedAxios.post).toHaveBeenCalledWith(
                '/api/v1/web/uploads/',
                expect.any(FormData)
            );
        });

        // Check that success event was dispatched
        await waitFor(() => {
            expect(component.component.$$.ctx[0]).toBe(false); // Modal should be closed
        });
    });

    it('handles file selection', async () => {
        render(CrackableUploadModal, {
            props: {
                open: true,
                projectId: 1
            }
        });

        // Switch to file mode
        const fileModeButton = screen.getByTestId('file-mode-button');
        await fireEvent.click(fileModeButton);

        const fileInput = screen.getByTestId('file-input');
        const file = new File(['test content'], 'test.shadow', { type: 'text/plain' });

        await fireEvent.change(fileInput, {
            target: { files: [file] }
        });

        await waitFor(() => {
            expect(screen.getByText('Selected: test.shadow')).toBeInTheDocument();
        });
    });

    it('uploads file with presigned URL', async () => {
        const mockUploadResponse = {
            data: {
                resource_id: 123,
                presigned_url: 'https://s3.example.com/upload-url',
                resource: {
                    file_name: 'test.shadow'
                }
            }
        };

        mockedAxios.post.mockResolvedValueOnce(mockUploadResponse);
        mockedAxios.put.mockResolvedValueOnce({});

        render(CrackableUploadModal, {
            props: {
                open: true,
                projectId: 1
            }
        });

        // Switch to file mode
        const fileModeButton = screen.getByTestId('file-mode-button');
        await fireEvent.click(fileModeButton);

        const fileInput = screen.getByTestId('file-input');
        const uploadButton = screen.getByTestId('upload-button');
        const file = new File(['test content'], 'test.shadow', { type: 'text/plain' });

        await fireEvent.change(fileInput, {
            target: { files: [file] }
        });

        await fireEvent.click(uploadButton);

        await waitFor(() => {
            expect(mockedAxios.post).toHaveBeenCalledWith(
                '/api/v1/web/uploads/',
                expect.any(FormData)
            );
            expect(mockedAxios.put).toHaveBeenCalledWith(
                'https://s3.example.com/upload-url',
                file,
                {
                    headers: {
                        'Content-Type': 'text/plain'
                    }
                }
            );
        });
    });

    it('disables upload button when no content is provided', () => {
        render(CrackableUploadModal, {
            props: {
                open: true,
                projectId: 1
            }
        });

        const uploadButton = screen.getByTestId('upload-button');
        expect(uploadButton).toBeDisabled();
    });

    it('shows confidence colors correctly', async () => {
        const mockHashGuessResponse = {
            data: {
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
                        confidence: 0.45
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
            target: { value: 'test hash content' }
        });

        await fireEvent.click(validateButton);

        await waitFor(() => {
            const badges = screen.getAllByText(/\d+%/);
            expect(badges).toHaveLength(3);
            expect(screen.getByText('95%')).toBeInTheDocument();
            expect(screen.getByText('65%')).toBeInTheDocument();
            expect(screen.getByText('45%')).toBeInTheDocument();
        });
    });
});
