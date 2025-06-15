import type { Campaign, CampaignMetrics, CampaignProgress } from '$lib/types/campaign';

// Store state interfaces
interface CampaignState {
	campaigns: Campaign[];
	loading: boolean;
	error: string | null;
}

interface CampaignDataState {
	metrics: Record<number, CampaignMetrics>;
	progress: Record<number, CampaignProgress>;
	loading: Record<number, boolean>;
	errors: Record<number, string | null>;
}

// Create reactive state using SvelteKit 5 runes
const campaignState = $state<CampaignState>({
	campaigns: [],
	loading: false,
	error: null
});

const campaignDataState = $state<CampaignDataState>({
	metrics: {},
	progress: {},
	loading: {},
	errors: {}
});

// Derived stores at module level
const campaigns = $derived(campaignState.campaigns);
const campaignsLoading = $derived(campaignState.loading);
const campaignsError = $derived(campaignState.error);

// Export functions that return the derived values
export function getCampaigns() {
	return campaigns;
}

export function getCampaignsLoading() {
	return campaignsLoading;
}

export function getCampaignsError() {
	return campaignsError;
}

// Campaign store actions
export const campaignsStore = {
	// Basic campaign operations
	setCampaigns: (campaigns: Campaign[]) => {
		campaignState.campaigns = campaigns;
		campaignState.loading = false;
		campaignState.error = null;
	},

	addCampaign: (campaign: Campaign) => {
		campaignState.campaigns = [...campaignState.campaigns, campaign];
	},

	updateCampaign: (id: number, updates: Partial<Campaign>) => {
		campaignState.campaigns = campaignState.campaigns.map((c) =>
			c.id === id ? { ...c, ...updates } : c
		);
	},

	removeCampaign: (id: number) => {
		campaignState.campaigns = campaignState.campaigns.filter((c) => c.id !== id);
		// Clean up associated data
		delete campaignDataState.metrics[id];
		delete campaignDataState.progress[id];
		delete campaignDataState.loading[id];
		delete campaignDataState.errors[id];
	},

	setLoading: (loading: boolean) => {
		campaignState.loading = loading;
	},

	setError: (error: string | null) => {
		campaignState.error = error;
	},

	// Campaign data operations
	setCampaignMetrics: (campaignId: number, metrics: CampaignMetrics) => {
		campaignDataState.metrics[campaignId] = metrics;
		campaignDataState.loading[campaignId] = false;
		campaignDataState.errors[campaignId] = null;
	},

	setCampaignProgress: (campaignId: number, progress: CampaignProgress) => {
		campaignDataState.progress[campaignId] = progress;
		campaignDataState.loading[campaignId] = false;
		campaignDataState.errors[campaignId] = null;
	},

	setCampaignData: (campaignId: number, metrics: CampaignMetrics, progress: CampaignProgress) => {
		campaignDataState.metrics[campaignId] = metrics;
		campaignDataState.progress[campaignId] = progress;
		campaignDataState.loading[campaignId] = false;
		campaignDataState.errors[campaignId] = null;
	},

	setCampaignLoading: (campaignId: number, loading: boolean) => {
		campaignDataState.loading[campaignId] = loading;
	},

	setCampaignError: (campaignId: number, error: string | null) => {
		campaignDataState.errors[campaignId] = error;
		campaignDataState.loading[campaignId] = false;
	},

	// Getters
	getCampaignMetrics: (campaignId: number): CampaignMetrics | null => {
		return campaignDataState.metrics[campaignId] || null;
	},

	getCampaignProgress: (campaignId: number): CampaignProgress | null => {
		return campaignDataState.progress[campaignId] || null;
	},

	isCampaignLoading: (campaignId: number): boolean => {
		return campaignDataState.loading[campaignId] || false;
	},

	getCampaignError: (campaignId: number): string | null => {
		return campaignDataState.errors[campaignId] || null;
	},

	// API operations
	async updateCampaignData(campaignId: number): Promise<void> {
		this.setCampaignLoading(campaignId, true);

		try {
			// Fetch both metrics and progress in parallel
			const [metricsResponse, progressResponse] = await Promise.all([
				fetch(`/api/v1/web/campaigns/${campaignId}/metrics`),
				fetch(`/api/v1/web/campaigns/${campaignId}/progress`)
			]);

			if (!metricsResponse.ok || !progressResponse.ok) {
				throw new Error('Failed to fetch campaign data');
			}

			const [metrics, progress] = await Promise.all([
				metricsResponse.json(),
				progressResponse.json()
			]);

			this.setCampaignData(campaignId, metrics, progress);
		} catch (error) {
			const errorMessage = error instanceof Error ? error.message : 'Unknown error';
			this.setCampaignError(campaignId, errorMessage);
		}
	},

	// Hydration from SSR data
	hydrateCampaignData(
		campaignId: number,
		metrics?: CampaignMetrics,
		progress?: CampaignProgress
	) {
		if (metrics && progress) {
			this.setCampaignData(campaignId, metrics, progress);
		} else if (metrics) {
			this.setCampaignMetrics(campaignId, metrics);
		} else if (progress) {
			this.setCampaignProgress(campaignId, progress);
		}
	}
};
