import { render, fireEvent, waitFor } from '@testing-library/svelte';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import LiveUpdatesToggle from './LiveUpdatesToggle.svelte';

// Mock fetch
global.fetch = vi.fn();

describe('LiveUpdatesToggle', () => {
    beforeEach(() => {
        vi.resetAllMocks();
    });

    it('renders enabled state correctly', () => {
        const { getByText } = render(LiveUpdatesToggle, {
            props: {
                attackId: 'test-attack-id',
                enabled: true
            }
        });

        expect(getByText('Live Updates:')).toBeInTheDocument();
        expect(getByText('Enabled')).toBeInTheDocument();
        expect(getByText('Disable')).toBeInTheDocument();
    });

    it('renders disabled state correctly', () => {
        const { getByText } = render(LiveUpdatesToggle, {
            props: {
                attackId: 'test-attack-id',
                enabled: false
            }
        });

        expect(getByText('Live Updates:')).toBeInTheDocument();
        expect(getByText('Disabled')).toBeInTheDocument();
        expect(getByText('Enable')).toBeInTheDocument();
    });

    it('calls API when toggling from enabled to disabled', async () => {
        const mockFetch = vi.mocked(fetch);
        mockFetch.mockResolvedValueOnce({
            ok: true
        } as Response);

        const onToggle = vi.fn();
        const { getByText } = render(LiveUpdatesToggle, {
            props: {
                attackId: 'test-attack-id',
                enabled: true,
                onToggle
            }
        });

        const disableButton = getByText('Disable');
        await fireEvent.click(disableButton);

        await waitFor(() => {
            expect(mockFetch).toHaveBeenCalledWith(
                '/api/v1/web/attacks/test-attack-id/disable_live_updates',
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ enabled: false })
                }
            );
            expect(onToggle).toHaveBeenCalledWith(false);
        });
    });

    it('calls API when toggling from disabled to enabled', async () => {
        const mockFetch = vi.mocked(fetch);
        mockFetch.mockResolvedValueOnce({
            ok: true
        } as Response);

        const onToggle = vi.fn();
        const { getByText } = render(LiveUpdatesToggle, {
            props: {
                attackId: 'test-attack-id',
                enabled: false,
                onToggle
            }
        });

        const enableButton = getByText('Enable');
        await fireEvent.click(enableButton);

        await waitFor(() => {
            expect(mockFetch).toHaveBeenCalledWith(
                '/api/v1/web/attacks/test-attack-id/disable_live_updates',
                {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ enabled: true })
                }
            );
            expect(onToggle).toHaveBeenCalledWith(true);
        });
    });

    it('handles API errors gracefully', async () => {
        const mockFetch = vi.mocked(fetch);
        mockFetch.mockRejectedValueOnce(new Error('Network error'));

        const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {});

        const { getByText } = render(LiveUpdatesToggle, {
            props: {
                attackId: 'test-attack-id',
                enabled: true
            }
        });

        const disableButton = getByText('Disable');
        await fireEvent.click(disableButton);

        await waitFor(() => {
            expect(consoleSpy).toHaveBeenCalledWith(
                'Failed to toggle live updates:',
                expect.any(Error)
            );
        });

        consoleSpy.mockRestore();
    });
});
