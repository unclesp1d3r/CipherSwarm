import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import CampaignProgress from './CampaignProgress.svelte';
import { campaignsStore } from '$lib/stores/campaigns';
import type { CampaignProgress as CampaignProgressType } from '$lib/types/campaign';

// Mock the campaigns store
vi.mock('$lib/stores/campaigns', () => ({
	campaignsStore: {
		setCampaignProgress: vi.fn(),
		getCampaignProgress: vi.fn(),
		isCampaignLoading: vi.fn(),
		getCampaignError: vi.fn(),
		updateCampaignData: vi.fn()
	}
}));

const mockCampaignsStore = vi.mocked(campaignsStore);

describe('CampaignProgress', () => {
	const mockProgress: CampaignProgressType = {
		total_tasks: 10,
		active_agents: 2,
		completed_tasks: 4,
		pending_tasks: 3,
		active_tasks: 2,
		failed_tasks: 1,
		percentage_complete: 40.0,
		overall_status: 'running',
		active_attack_id: 5
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
				initialProgress: mockProgress
			}
		});

		expect(screen.getByTestId('campaign-progress-card')).toBeInTheDocument();
		expect(screen.getByText('Campaign Progress')).toBeInTheDocument();
		expect(screen.getByTestId('progress-percentage')).toBeInTheDocument();
		expect(screen.getByTestId('progress-status')).toBeInTheDocument();
		expect(screen.getByTestId('total-tasks')).toBeInTheDocument();
		expect(screen.getByTestId('active-agents')).toBeInTheDocument();
		expect(screen.getByTestId('completed-tasks')).toBeInTheDocument();
	});

	it('displays correct progress values', () => {
		render(CampaignProgress, {
			props: {
				campaignId: 2,
				initialProgress: mockProgress
			}
		});

		expect(screen.getByTestId('progress-percentage')).toHaveTextContent('40.0%');
		expect(screen.getByTestId('progress-status')).toHaveTextContent('Running');
		expect(screen.getByTestId('total-tasks')).toHaveTextContent('Total Tasks: 10');
		expect(screen.getByTestId('active-agents')).toHaveTextContent('Active Agents: 2');
		expect(screen.getByTestId('completed-tasks')).toHaveTextContent('Completed: 4');
		expect(screen.getByTestId('active-tasks')).toHaveTextContent('Active: 2');
		expect(screen.getByTestId('pending-tasks')).toHaveTextContent('Pending: 3');
		expect(screen.getByTestId('failed-tasks')).toHaveTextContent('Failed: 1');
	});

	it('displays progress bar with correct value', () => {
		render(CampaignProgress, {
			props: {
				campaignId: 3,
				initialProgress: mockProgress
			}
		});

		const progressBar = screen.getByTestId('campaign-progress-bar');
		expect(progressBar).toHaveAttribute('data-value', '40');
	});

	it('shows loading state when store indicates loading', () => {
		mockCampaignsStore.isCampaignLoading.mockReturnValue(true);

		render(CampaignProgress, {
			props: {
				campaignId: 4
			}
		});

		expect(screen.getByTestId('progress-loading')).toBeInTheDocument();
		expect(screen.getByText('Loading...')).toBeInTheDocument();
	});

	it('shows error state when store has error', () => {
		mockCampaignsStore.getCampaignError.mockReturnValue('Failed to load progress');

		render(CampaignProgress, {
			props: {
				campaignId: 5
			}
		});

		expect(screen.getByTestId('progress-error')).toBeInTheDocument();
		expect(screen.getByText('Failed to load progress')).toBeInTheDocument();
	});

	it('handles zero progress correctly', () => {
		const zeroProgress: CampaignProgressType = {
			total_tasks: 0,
			active_agents: 0,
			completed_tasks: 0,
			pending_tasks: 0,
			active_tasks: 0,
			failed_tasks: 0,
			percentage_complete: 0.0,
			overall_status: 'pending',
			active_attack_id: null
		};

		render(CampaignProgress, {
			props: {
				campaignId: 6,
				initialProgress: zeroProgress
			}
		});

		expect(screen.getByTestId('progress-percentage')).toHaveTextContent('0.0%');
		expect(screen.getByTestId('progress-status')).toHaveTextContent('Pending');
		expect(screen.getByTestId('total-tasks')).toHaveTextContent('Total Tasks: 0');
		expect(screen.getByTestId('active-agents')).toHaveTextContent('Active Agents: 0');
		expect(screen.getByTestId('completed-tasks')).toHaveTextContent('Completed: 0');
	});

	it('handles missing optional props', () => {
		// When no initial progress and store returns null, should show fallback loading
		render(CampaignProgress, {
			props: {
				campaignId: 7
			}
		});

		// Should handle missing initialProgress and enableAutoRefresh gracefully
		expect(screen.getByTestId('no-progress-data')).toBeInTheDocument();
		expect(screen.getByText('Loading...')).toBeInTheDocument();
	});
});
