import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import CampaignProgress from './CampaignProgress.svelte';
import { campaignsStore } from '$lib/stores/campaigns.svelte';
import type { CampaignProgress as CampaignProgressType } from '$lib/schemas/campaigns';

// Mock the campaigns store
vi.mock('$lib/stores/campaigns.svelte', () => ({
    campaignsStore: {
        setCampaignProgress: vi.fn(),
        getCampaignProgress: vi.fn(),
        isCampaignLoading: vi.fn(),
        getCampaignError: vi.fn(),
        updateCampaignData: vi.fn(),
    },
}));

const mockCampaignsStore = vi.mocked(campaignsStore);

describe('CampaignProgress', () => {
    const mockProgress: CampaignProgressType = {
        total_tasks: 10,
        active_agents: 3,
        completed_tasks: 5,
        pending_tasks: 3,
        active_tasks: 2,
        failed_tasks: 0,
        percentage_complete: 50.0,
        overall_status: 'running',
        active_attack_id: 1,
    };

    beforeEach(() => {
        // Reset all mocks
        vi.clearAllMocks();

        // Set default mock returns
        mockCampaignsStore.getCampaignProgress.mockReturnValue(null);
        mockCampaignsStore.isCampaignLoading.mockReturnValue(false);
        mockCampaignsStore.getCampaignError.mockReturnValue(null);
    });

    it('renders with initial progress data', () => {
        render(CampaignProgress, {
            props: {
                campaignId: 1,
                initialProgress: mockProgress,
            },
        });

        expect(screen.getByTestId('campaign-progress-card')).toBeInTheDocument();
        expect(screen.getByText('Campaign Progress')).toBeInTheDocument();
        expect(screen.getByTestId('total-tasks')).toBeInTheDocument();
        expect(screen.getByTestId('active-agents')).toBeInTheDocument();
        expect(screen.getByTestId('completed-tasks')).toBeInTheDocument();
        expect(screen.getByTestId('pending-tasks')).toBeInTheDocument();
        expect(screen.getByTestId('active-tasks')).toBeInTheDocument();
        expect(screen.getByTestId('failed-tasks')).toBeInTheDocument();
        expect(screen.getByTestId('progress-percentage')).toBeInTheDocument();
        expect(screen.getByTestId('progress-status')).toBeInTheDocument();
    });

    it('displays correct progress values', () => {
        render(CampaignProgress, {
            props: {
                campaignId: 2,
                initialProgress: mockProgress,
            },
        });

        expect(screen.getByTestId('total-tasks')).toHaveTextContent('Total Tasks: 10');
        expect(screen.getByTestId('active-agents')).toHaveTextContent('Active Agents: 3');
        expect(screen.getByTestId('completed-tasks')).toHaveTextContent('Completed: 5');
        expect(screen.getByTestId('pending-tasks')).toHaveTextContent('Pending: 3');
        expect(screen.getByTestId('active-tasks')).toHaveTextContent('Active: 2');
        expect(screen.getByTestId('failed-tasks')).toHaveTextContent('Failed: 0');
        expect(screen.getByTestId('progress-percentage')).toHaveTextContent('50.0%');
        expect(screen.getByTestId('progress-status')).toHaveTextContent('Running');
    });

    it('displays progress bar with correct value', () => {
        render(CampaignProgress, {
            props: {
                campaignId: 3,
                initialProgress: mockProgress,
            },
        });

        const progressBar = screen.getByTestId('campaign-progress-bar');
        expect(progressBar).toHaveAttribute('data-value', '50');
    });

    it('shows loading state when store indicates loading', () => {
        mockCampaignsStore.isCampaignLoading.mockReturnValue(true);

        render(CampaignProgress, {
            props: {
                campaignId: 4,
            },
        });

        expect(screen.getByTestId('progress-loading')).toBeInTheDocument();
        expect(screen.getByText('Loading...')).toBeInTheDocument();
    });

    it('shows error state when store has error', () => {
        mockCampaignsStore.getCampaignError.mockReturnValue('Failed to load progress');

        render(CampaignProgress, {
            props: {
                campaignId: 5,
            },
        });

        expect(screen.getByTestId('progress-error')).toBeInTheDocument();
        expect(screen.getByText('Failed to load progress')).toBeInTheDocument();
    });

    it('handles zero values correctly', () => {
        const zeroProgress: CampaignProgressType = {
            total_tasks: 0,
            active_agents: 0,
            completed_tasks: 0,
            pending_tasks: 0,
            active_tasks: 0,
            failed_tasks: 0,
            percentage_complete: 0.0,
            overall_status: 'pending',
            active_attack_id: undefined,
        };

        render(CampaignProgress, {
            props: {
                campaignId: 6,
                initialProgress: zeroProgress,
            },
        });

        expect(screen.getByTestId('total-tasks')).toHaveTextContent('Total Tasks: 0');
        expect(screen.getByTestId('active-agents')).toHaveTextContent('Active Agents: 0');
        expect(screen.getByTestId('completed-tasks')).toHaveTextContent('Completed: 0');
        expect(screen.getByTestId('pending-tasks')).toHaveTextContent('Pending: 0');
        expect(screen.getByTestId('active-tasks')).toHaveTextContent('Active: 0');
        expect(screen.getByTestId('failed-tasks')).toHaveTextContent('Failed: 0');
        expect(screen.getByTestId('progress-percentage')).toHaveTextContent('0.0%');
        expect(screen.getByTestId('progress-status')).toHaveTextContent('Pending');
    });

    it('handles missing optional props', () => {
        const minimalProgress: CampaignProgressType = {
            total_tasks: 5,
            active_agents: 1,
            completed_tasks: 2,
            pending_tasks: 2,
            active_tasks: 1,
            failed_tasks: 0,
            percentage_complete: 40.0,
        };

        render(CampaignProgress, {
            props: {
                campaignId: 7,
                initialProgress: minimalProgress,
            },
        });

        expect(screen.getByTestId('total-tasks')).toHaveTextContent('Total Tasks: 5');
        expect(screen.getByTestId('progress-percentage')).toHaveTextContent('40.0%');
    });
});
