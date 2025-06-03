import { render, screen } from '@testing-library/svelte';
import { describe, it, expect } from 'vitest';
import CampaignsList from '$lib/components/campaigns/CampaignsList.svelte';

describe('CampaignsList', () => {
    it('renders campaign list with rows', () => {
        render(CampaignsList);
        expect(screen.getByText('Campaigns')).toBeInTheDocument();
        expect(screen.getByText('Fall PenTest Roundup')).toBeInTheDocument();
        expect(screen.getByText('Sensitive Campaign')).toBeInTheDocument();
    });

    it('shows empty state if no campaigns', () => {
        render(CampaignsList, { campaigns: [] });
        expect(screen.getByText(/No campaigns found/i)).toBeInTheDocument();
    });

    it('shows error state', () => {
        render(CampaignsList, { error: 'Failed to load' });
        expect(screen.getByText(/Failed to load/i)).toBeInTheDocument();
    });
}); 