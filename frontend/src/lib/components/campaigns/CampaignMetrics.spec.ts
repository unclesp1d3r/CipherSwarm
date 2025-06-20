import { describe, it, expect, beforeEach, vi } from 'vitest';
import { render, screen } from '@testing-library/svelte';
import CampaignMetrics from './CampaignMetrics.svelte';
import { campaignsStore } from '$lib/stores/campaigns.svelte';
import type { CampaignMetrics as CampaignMetricsType } from '$lib/types/campaign';

// Mock the campaigns store
vi.mock('$lib/stores/campaigns.svelte', () => ({
    campaignsStore: {
        setCampaignMetrics: vi.fn(),
        getCampaignMetrics: vi.fn(),
        isCampaignLoading: vi.fn(),
        getCampaignError: vi.fn(),
        updateCampaignData: vi.fn()
    }
}));

const mockCampaignsStore = vi.mocked(campaignsStore);

describe('CampaignMetrics', () => {
    const mockMetrics: CampaignMetricsType = {
        total_hashes: 1000,
        cracked_hashes: 250,
        uncracked_hashes: 750,
        percent_cracked: 25.0,
        progress_percent: 50.0
    };

    beforeEach(() => {
        // Reset all mocks
        vi.clearAllMocks();

        // Set default mock returns
        mockCampaignsStore.getCampaignMetrics.mockReturnValue(null);
        mockCampaignsStore.isCampaignLoading.mockReturnValue(false);
        mockCampaignsStore.getCampaignError.mockReturnValue(null);
    });

    it('renders with initial metrics data', () => {
        render(CampaignMetrics, {
            props: {
                campaignId: 1,
                initialMetrics: mockMetrics
            }
        });

        expect(screen.getByTestId('campaign-metrics-card')).toBeInTheDocument();
        expect(screen.getByText('Campaign Metrics')).toBeInTheDocument();
        expect(screen.getByTestId('total-hashes')).toBeInTheDocument();
        expect(screen.getByTestId('cracked-hashes')).toBeInTheDocument();
        expect(screen.getByTestId('uncracked-hashes')).toBeInTheDocument();
        expect(screen.getByTestId('percent-cracked')).toBeInTheDocument();
        expect(screen.getByTestId('cracking-percentage')).toBeInTheDocument();
        expect(screen.getByTestId('overall-percentage')).toBeInTheDocument();
    });

    it('displays correct metrics values', () => {
        render(CampaignMetrics, {
            props: {
                campaignId: 2,
                initialMetrics: mockMetrics
            }
        });

        // Check specific data-testid elements with proper spacing
        expect(screen.getByTestId('total-hashes')).toHaveTextContent('Total Hashes: 1,000');
        expect(screen.getByTestId('cracked-hashes')).toHaveTextContent('Cracked: 250');
        expect(screen.getByTestId('uncracked-hashes')).toHaveTextContent('Remaining: 750');
        expect(screen.getByTestId('percent-cracked')).toHaveTextContent('Progress: 25.0%');
        expect(screen.getByTestId('cracking-percentage')).toHaveTextContent('25.0%');
        expect(screen.getByTestId('overall-percentage')).toHaveTextContent('50.0%');
        expect(screen.getByTestId('metrics-summary')).toHaveTextContent(
            '250 of 1,000 hashes cracked (25.0%)'
        );
    });

    it('displays progress bars with correct values', () => {
        render(CampaignMetrics, {
            props: {
                campaignId: 3,
                initialMetrics: mockMetrics
            }
        });

        const crackingProgressBar = screen.getByTestId('campaign-cracking-progress-bar');
        const overallProgressBar = screen.getByTestId('campaign-overall-progress-bar');

        expect(crackingProgressBar).toHaveAttribute('data-value', '25');
        expect(overallProgressBar).toHaveAttribute('data-value', '50');
    });

    it('shows loading state when store indicates loading', () => {
        mockCampaignsStore.isCampaignLoading.mockReturnValue(true);

        render(CampaignMetrics, {
            props: {
                campaignId: 4
            }
        });

        expect(screen.getByTestId('metrics-loading')).toBeInTheDocument();
        expect(screen.getByText('Loading...')).toBeInTheDocument();
    });

    it('shows error state when store has error', () => {
        mockCampaignsStore.getCampaignError.mockReturnValue('Failed to load metrics');

        render(CampaignMetrics, {
            props: {
                campaignId: 5
            }
        });

        expect(screen.getByTestId('metrics-error')).toBeInTheDocument();
        expect(screen.getByText('Failed to load metrics')).toBeInTheDocument();
    });

    it('handles zero values correctly', () => {
        const zeroMetrics: CampaignMetricsType = {
            total_hashes: 0,
            cracked_hashes: 0,
            uncracked_hashes: 0,
            percent_cracked: 0.0,
            progress_percent: 0.0
        };

        render(CampaignMetrics, {
            props: {
                campaignId: 6,
                initialMetrics: zeroMetrics
            }
        });

        // Use specific test IDs to avoid ambiguity
        expect(screen.getByTestId('total-hashes')).toHaveTextContent('Total Hashes: 0');
        expect(screen.getByTestId('cracked-hashes')).toHaveTextContent('Cracked: 0');
        expect(screen.getByTestId('uncracked-hashes')).toHaveTextContent('Remaining: 0');
        expect(screen.getByTestId('percent-cracked')).toHaveTextContent('Progress: 0.0%');
        expect(screen.getByTestId('cracking-percentage')).toHaveTextContent('0.0%');
        expect(screen.getByTestId('overall-percentage')).toHaveTextContent('0.0%');
    });

    it('handles missing optional props', () => {
        // When no initial metrics and store returns null, should show fallback loading
        render(CampaignMetrics, {
            props: {
                campaignId: 7
            }
        });

        // Should handle missing initialMetrics and enableAutoRefresh gracefully
        expect(screen.getByTestId('no-metrics-data')).toBeInTheDocument();
        expect(screen.getByText('Loading...')).toBeInTheDocument();
    });
});
