import { writable, derived, get } from 'svelte/store';
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

// Create base stores
const campaignState = writable<CampaignState>({
	campaigns: [],
	loading: false,
	error: null
});

const campaignDataState = writable<CampaignDataState>({
	metrics: {},
	progress: {},
	loading: {},
	errors: {}
});

// Derived stores for easy access
export const campaigns = derived(campaignState, ($state) => $state.campaigns);
export const campaignsLoading = derived(campaignState, ($state) => $state.loading);
export const campaignsError = derived(campaignState, ($state) => $state.error);

// Campaign store actions
export const campaignsStore = {
	// Basic campaign operations
	setCampaigns: (campaigns: Campaign[]) => {
		campaignState.update((state) => ({ ...state, campaigns, loading: false, error: null }));
	},

	addCampaign: (campaign: Campaign) => {
		campaignState.update((state) => ({
			...state,
			campaigns: [...state.campaigns, campaign]
		}));
	},

	updateCampaign: (id: number, updates: Partial<Campaign>) => {
		campaignState.update((state) => ({
			...state,
			campaigns: state.campaigns.map((c) => (c.id === id ? { ...c, ...updates } : c))
		}));
	},

	removeCampaign: (id: number) => {
		campaignState.update((state) => ({
			...state,
			campaigns: state.campaigns.filter((c) => c.id !== id)
		}));
		// Clean up associated data
		campaignDataState.update((state) => {
			const { [id]: removedMetrics, ...metrics } = state.metrics;
			const { [id]: removedProgress, ...progress } = state.progress;
			const { [id]: removedLoading, ...loading } = state.loading;
			const { [id]: removedErrors, ...errors } = state.errors;
			return { metrics, progress, loading, errors };
		});
	},

	setLoading: (loading: boolean) => {
		campaignState.update((state) => ({ ...state, loading }));
	},

	setError: (error: string | null) => {
		campaignState.update((state) => ({ ...state, error }));
	},

	// Campaign data operations
	setCampaignMetrics: (campaignId: number, metrics: CampaignMetrics) => {
		campaignDataState.update((state) => ({
			...state,
			metrics: { ...state.metrics, [campaignId]: metrics },
			loading: { ...state.loading, [campaignId]: false },
			errors: { ...state.errors, [campaignId]: null }
		}));
	},

	setCampaignProgress: (campaignId: number, progress: CampaignProgress) => {
		campaignDataState.update((state) => ({
			...state,
			progress: { ...state.progress, [campaignId]: progress },
			loading: { ...state.loading, [campaignId]: false },
			errors: { ...state.errors, [campaignId]: null }
		}));
	},

	setCampaignData: (campaignId: number, metrics: CampaignMetrics, progress: CampaignProgress) => {
		campaignDataState.update((state) => ({
			...state,
			metrics: { ...state.metrics, [campaignId]: metrics },
			progress: { ...state.progress, [campaignId]: progress },
			loading: { ...state.loading, [campaignId]: false },
			errors: { ...state.errors, [campaignId]: null }
		}));
	},

	setCampaignLoading: (campaignId: number, loading: boolean) => {
		campaignDataState.update((state) => ({
			...state,
			loading: { ...state.loading, [campaignId]: loading }
		}));
	},

	setCampaignError: (campaignId: number, error: string | null) => {
		campaignDataState.update((state) => ({
			...state,
			errors: { ...state.errors, [campaignId]: error },
			loading: { ...state.loading, [campaignId]: false }
		}));
	},

	// Getters
	getCampaignMetrics: (campaignId: number): CampaignMetrics | null => {
		const state = get(campaignDataState);
		return state.metrics[campaignId] || null;
	},

	getCampaignProgress: (campaignId: number): CampaignProgress | null => {
		const state = get(campaignDataState);
		return state.progress[campaignId] || null;
	},

	isCampaignLoading: (campaignId: number): boolean => {
		const state = get(campaignDataState);
		return state.loading[campaignId] || false;
	},

	getCampaignError: (campaignId: number): string | null => {
		const state = get(campaignDataState);
		return state.errors[campaignId] || null;
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

// Derived stores for specific campaign data
export function createCampaignMetricsStore(campaignId: number) {
	return derived(campaignDataState, ($state) => $state.metrics[campaignId] || null);
}

export function createCampaignProgressStore(campaignId: number) {
	return derived(campaignDataState, ($state) => $state.progress[campaignId] || null);
}

export function createCampaignLoadingStore(campaignId: number) {
	return derived(campaignDataState, ($state) => $state.loading[campaignId] || false);
}

export function createCampaignErrorStore(campaignId: number) {
	return derived(campaignDataState, ($state) => $state.errors[campaignId] || null);
}
