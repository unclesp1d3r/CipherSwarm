import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/svelte';
import axios from 'axios';
import CampaignProgress from './CampaignProgress.svelte';

// Mock axios
vi.mock('axios', () => ({
	default: {
		get: vi.fn()
	}
}));

/* eslint-disable  @typescript-eslint/no-explicit-any */
const mockedAxios = axios as any;

describe('CampaignProgress', () => {
	const mockProgressData = {
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

	beforeEach(() => {
		vi.clearAllMocks();
		vi.useFakeTimers();
	});

	afterEach(() => {
		vi.useRealTimers();
	});

	it('renders loading state initially', () => {
		mockedAxios.get.mockImplementation(() => new Promise(() => {})); // Never resolves

		render(CampaignProgress, { props: { campaignId: 1 } });

		expect(screen.getByTestId('progress-loading')).toBeInTheDocument();
		expect(screen.getByText('Loading progress...')).toBeInTheDocument();
	});

	it('renders progress data correctly', async () => {
		mockedAxios.get.mockResolvedValue({ data: mockProgressData });

		render(CampaignProgress, { props: { campaignId: 1 } });

		await waitFor(() => {
			expect(screen.getByTestId('campaign-progress-card')).toBeInTheDocument();
		});

		// Check title
		expect(screen.getByText('Campaign Progress')).toBeInTheDocument();

		// Check progress percentage
		expect(screen.getByTestId('progress-percentage')).toHaveTextContent('45.5%');

		// Check status badge
		expect(screen.getByTestId('progress-status')).toHaveTextContent('Running');

		// Check active agents
		expect(screen.getByTestId('active-agents')).toHaveTextContent('3');

		// Check task breakdown
		expect(screen.getByTestId('total-tasks')).toHaveTextContent('100');
		expect(screen.getByTestId('completed-tasks')).toHaveTextContent('45');
		expect(screen.getByTestId('active-tasks')).toHaveTextContent('20');
		expect(screen.getByTestId('pending-tasks')).toHaveTextContent('30');
		expect(screen.getByTestId('failed-tasks')).toHaveTextContent('5');

		// Check active attack ID
		expect(screen.getByTestId('active-attack')).toHaveTextContent('#1');
	});

	it('handles API error gracefully', async () => {
		mockedAxios.get.mockRejectedValue(new Error('API Error'));

		render(CampaignProgress, { props: { campaignId: 1 } });

		await waitFor(() => {
			expect(screen.getByTestId('progress-error')).toBeInTheDocument();
		});

		expect(screen.getByText('Failed to load campaign progress.')).toBeInTheDocument();
	});

	it('handles different status badges correctly', async () => {
		const statuses = [
			{ status: 'completed', label: 'Completed' },
			{ status: 'failed', label: 'Failed' },
			{ status: 'pending', label: 'Pending' },
			{ status: null, label: 'Unknown' }
		];

		for (const { status, label } of statuses) {
			const progressData = { ...mockProgressData, overall_status: status };
			mockedAxios.get.mockResolvedValue({ data: progressData });

			const { unmount } = render(CampaignProgress, { props: { campaignId: 1 } });

			await waitFor(() => {
				expect(screen.getByTestId('progress-status')).toHaveTextContent(label);
			});

			unmount();
		}
	});

	it('hides active attack when null', async () => {
		const progressData = { ...mockProgressData, active_attack_id: null };
		mockedAxios.get.mockResolvedValue({ data: progressData });

		render(CampaignProgress, { props: { campaignId: 1 } });

		await waitFor(() => {
			expect(screen.getByTestId('campaign-progress-card')).toBeInTheDocument();
		});

		expect(screen.queryByTestId('active-attack')).not.toBeInTheDocument();
	});

	it('displays no data message when progress is null', async () => {
		mockedAxios.get.mockResolvedValue({ data: null });

		render(CampaignProgress, { props: { campaignId: 1 } });

		await waitFor(() => {
			expect(screen.getByTestId('no-progress-data')).toBeInTheDocument();
		});

		expect(screen.getByText('No progress data available.')).toBeInTheDocument();
	});

	it('makes API call with correct campaign ID', async () => {
		mockedAxios.get.mockResolvedValue({ data: mockProgressData });

		render(CampaignProgress, { props: { campaignId: 123 } });

		await waitFor(() => {
			expect(mockedAxios.get).toHaveBeenCalledWith('/api/v1/web/campaigns/123/progress');
		});
	});

	it('sets up polling with custom refresh interval', async () => {
		mockedAxios.get.mockResolvedValue({ data: mockProgressData });

		render(CampaignProgress, { props: { campaignId: 1, refreshInterval: 2000 } });

		// Initial call
		await waitFor(() => {
			expect(mockedAxios.get).toHaveBeenCalledTimes(1);
		});

		// Advance timer by 2 seconds (custom interval)
		vi.advanceTimersByTime(2000);

		await waitFor(() => {
			expect(mockedAxios.get).toHaveBeenCalledTimes(2);
		});
	});

	it('clears error state on successful retry', async () => {
		// First call fails
		mockedAxios.get.mockRejectedValueOnce(new Error('API Error'));
		// Second call succeeds
		mockedAxios.get.mockResolvedValue({ data: mockProgressData });

		render(CampaignProgress, { props: { campaignId: 1 } });

		// Wait for error state
		await waitFor(() => {
			expect(screen.getByTestId('progress-error')).toBeInTheDocument();
		});

		// Advance timer to trigger retry
		vi.advanceTimersByTime(5000);

		// Wait for successful data load
		await waitFor(() => {
			expect(screen.getByTestId('campaign-progress-card')).toBeInTheDocument();
			expect(screen.queryByTestId('progress-error')).not.toBeInTheDocument();
		});
	});

	it('formats percentage correctly', async () => {
		const progressData = { ...mockProgressData, percentage_complete: 33.333333 };
		mockedAxios.get.mockResolvedValue({ data: progressData });

		render(CampaignProgress, { props: { campaignId: 1 } });

		await waitFor(() => {
			expect(screen.getByTestId('progress-percentage')).toHaveTextContent('33.3%');
		});
	});
});
