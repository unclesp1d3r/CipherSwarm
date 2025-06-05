import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/svelte';
import axios from 'axios';
import CampaignMetrics from './CampaignMetrics.svelte';

// Mock axios
vi.mock('axios', () => ({
    default: {
        get: vi.fn()
    }
}));

/* eslint-disable  @typescript-eslint/no-explicit-any */
const mockedAxios = axios as any;

describe('CampaignMetrics', () => {
    const mockMetricsData = {
        total_hashes: 50000,
        cracked_hashes: 12500,
        uncracked_hashes: 37500,
        percent_cracked: 25.0,
        progress_percent: 45.5
    };

    beforeEach(() => {
        vi.clearAllMocks();
        vi.useFakeTimers();
    });

    afterEach(() => {
        vi.useRealTimers();
    });

    it('renders loading state initially', () => {
        mockedAxios.get.mockImplementation(() => new Promise(() => { })); // Never resolves

        render(CampaignMetrics, { props: { campaignId: 1 } });

        expect(screen.getByTestId('metrics-loading')).toBeInTheDocument();
        expect(screen.getByText('Loading metrics...')).toBeInTheDocument();
    });

    it('renders metrics data correctly', async () => {
        mockedAxios.get.mockResolvedValue({ data: mockMetricsData });

        render(CampaignMetrics, { props: { campaignId: 1 } });

        await waitFor(() => {
            expect(screen.getByTestId('campaign-metrics-card')).toBeInTheDocument();
        });

        // Check title
        expect(screen.getByText('Campaign Metrics')).toBeInTheDocument();

        // Check hash statistics
        expect(screen.getByTestId('total-hashes')).toHaveTextContent('50,000');
        expect(screen.getByTestId('cracked-hashes')).toHaveTextContent('12,500');
        expect(screen.getByTestId('uncracked-hashes')).toHaveTextContent('37,500');

        // Check percentages
        expect(screen.getByTestId('percent-cracked')).toHaveTextContent('25.0%');
        expect(screen.getByTestId('progress-percent')).toHaveTextContent('45.5%');

        // Check progress bars
        expect(screen.getByTestId('campaign-cracking-progress-bar')).toBeInTheDocument();
        expect(screen.getByTestId('campaign-overall-progress-bar')).toBeInTheDocument();

        // Check percentage displays
        expect(screen.getByTestId('cracking-percentage')).toHaveTextContent('25.0%');
        expect(screen.getByTestId('overall-percentage')).toHaveTextContent('45.5%');

        // Check summary text
        expect(screen.getByTestId('metrics-summary')).toHaveTextContent(
            '12,500 of 50,000 hashes cracked (25.0%)'
        );
    });

    it('handles API error gracefully', async () => {
        mockedAxios.get.mockRejectedValue(new Error('API Error'));

        render(CampaignMetrics, { props: { campaignId: 1 } });

        await waitFor(() => {
            expect(screen.getByTestId('metrics-error')).toBeInTheDocument();
        });

        expect(screen.getByText('Failed to load campaign metrics.')).toBeInTheDocument();
    });

    it('handles zero hash metrics correctly', async () => {
        const zeroMetrics = {
            total_hashes: 0,
            cracked_hashes: 0,
            uncracked_hashes: 0,
            percent_cracked: 0,
            progress_percent: 0
        };

        mockedAxios.get.mockResolvedValue({ data: zeroMetrics });

        render(CampaignMetrics, { props: { campaignId: 1 } });

        await waitFor(() => {
            expect(screen.getByTestId('campaign-metrics-card')).toBeInTheDocument();
        });

        // Check that zero values are displayed correctly
        expect(screen.getByTestId('total-hashes')).toHaveTextContent('0');
        expect(screen.getByTestId('cracked-hashes')).toHaveTextContent('0');
        expect(screen.getByTestId('uncracked-hashes')).toHaveTextContent('0');
        expect(screen.getByTestId('percent-cracked')).toHaveTextContent('0.0%');

        // Summary should not be visible when total_hashes is 0
        expect(screen.queryByTestId('metrics-summary')).not.toBeInTheDocument();
    });

    it('displays no data message when metrics is null', async () => {
        mockedAxios.get.mockResolvedValue({ data: null });

        render(CampaignMetrics, { props: { campaignId: 1 } });

        await waitFor(() => {
            expect(screen.getByTestId('no-metrics-data')).toBeInTheDocument();
        });

        expect(screen.getByText('No metrics data available.')).toBeInTheDocument();
    });

    it('makes API call with correct campaign ID', async () => {
        mockedAxios.get.mockResolvedValue({ data: mockMetricsData });

        render(CampaignMetrics, { props: { campaignId: 456 } });

        await waitFor(() => {
            expect(mockedAxios.get).toHaveBeenCalledWith('/api/v1/web/campaigns/456/metrics');
        });
    });

    it('formats large numbers correctly', async () => {
        const largeMetrics = {
            total_hashes: 1234567,
            cracked_hashes: 987654,
            uncracked_hashes: 246913,
            percent_cracked: 80.0,
            progress_percent: 90.0
        };

        mockedAxios.get.mockResolvedValue({ data: largeMetrics });

        render(CampaignMetrics, { props: { campaignId: 1 } });

        await waitFor(() => {
            expect(screen.getByTestId('total-hashes')).toHaveTextContent('1,234,567');
            expect(screen.getByTestId('cracked-hashes')).toHaveTextContent('987,654');
            expect(screen.getByTestId('uncracked-hashes')).toHaveTextContent('246,913');
        });
    });

    it('sets up polling with custom refresh interval', async () => {
        mockedAxios.get.mockResolvedValue({ data: mockMetricsData });

        render(CampaignMetrics, { props: { campaignId: 1, refreshInterval: 3000 } });

        // Initial call
        await waitFor(() => {
            expect(mockedAxios.get).toHaveBeenCalledTimes(1);
        });

        // Advance timer by 3 seconds (custom interval)
        vi.advanceTimersByTime(3000);

        await waitFor(() => {
            expect(mockedAxios.get).toHaveBeenCalledTimes(2);
        });
    });

    it('clears error state on successful retry', async () => {
        // First call fails
        mockedAxios.get.mockRejectedValueOnce(new Error('API Error'));
        // Second call succeeds
        mockedAxios.get.mockResolvedValue({ data: mockMetricsData });

        render(CampaignMetrics, { props: { campaignId: 1 } });

        // Wait for error state
        await waitFor(() => {
            expect(screen.getByTestId('metrics-error')).toBeInTheDocument();
        });

        // Advance timer to trigger retry
        vi.advanceTimersByTime(5000);

        // Wait for successful data load
        await waitFor(() => {
            expect(screen.getByTestId('campaign-metrics-card')).toBeInTheDocument();
            expect(screen.queryByTestId('metrics-error')).not.toBeInTheDocument();
        });
    });

    it('formats percentages correctly', async () => {
        const metricsData = {
            ...mockMetricsData,
            percent_cracked: 33.333333,
            progress_percent: 66.666666
        };
        mockedAxios.get.mockResolvedValue({ data: metricsData });

        render(CampaignMetrics, { props: { campaignId: 1 } });

        await waitFor(() => {
            expect(screen.getByTestId('percent-cracked')).toHaveTextContent('33.3%');
            expect(screen.getByTestId('progress-percent')).toHaveTextContent('66.7%');
            expect(screen.getByTestId('cracking-percentage')).toHaveTextContent('33.3%');
            expect(screen.getByTestId('overall-percentage')).toHaveTextContent('66.7%');
        });
    });
});
