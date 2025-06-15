import { writable, derived, get } from 'svelte/store';
import { browser } from '$app/environment';
import type {
	ResourceListItem,
	ResourceDetailResponse,
	ResourcePreviewResponse,
	ResourceContentResponse,
	ResourceLinesResponse,
	AttackResourceType
} from '$lib/schemas/resources';

// Store state interfaces
interface ResourceState {
	resources: ResourceListItem[];
	loading: boolean;
	error: string | null;
	totalCount: number;
	page: number;
	pageSize: number;
	totalPages: number;
	resourceType: AttackResourceType | null;
}

interface ResourceDetailState {
	details: Record<string, ResourceDetailResponse>;
	previews: Record<string, ResourcePreviewResponse>;
	content: Record<string, ResourceContentResponse>;
	lines: Record<string, ResourceLinesResponse>;
	loading: Record<string, boolean>;
	errors: Record<string, string | null>;
}

interface ResourceCacheState {
	wordlists: ResourceListItem[];
	rulelists: ResourceListItem[];
	masklists: ResourceListItem[];
	charsets: ResourceListItem[];
	dynamicWordlists: ResourceListItem[];
	lastUpdated: Record<AttackResourceType, number>;
	loading: Record<AttackResourceType, boolean>;
}

// Create base stores
const resourceState = writable<ResourceState>({
	resources: [],
	loading: false,
	error: null,
	totalCount: 0,
	page: 1,
	pageSize: 25,
	totalPages: 0,
	resourceType: null
});

const resourceDetailState = writable<ResourceDetailState>({
	details: {},
	previews: {},
	content: {},
	lines: {},
	loading: {},
	errors: {}
});

const resourceCacheState = writable<ResourceCacheState>({
	wordlists: [],
	rulelists: [],
	masklists: [],
	charsets: [],
	dynamicWordlists: [],
	lastUpdated: {
		word_list: 0,
		rule_list: 0,
		mask_list: 0,
		charset: 0,
		dynamic_word_list: 0
	},
	loading: {
		word_list: false,
		rule_list: false,
		mask_list: false,
		charset: false,
		dynamic_word_list: false
	}
});

// Derived stores for easy access
export const resources = derived(resourceState, ($state) => $state.resources);
export const resourcesLoading = derived(resourceState, ($state) => $state.loading);
export const resourcesError = derived(resourceState, ($state) => $state.error);
export const resourcesPagination = derived(resourceState, ($state) => ({
	totalCount: $state.totalCount,
	page: $state.page,
	pageSize: $state.pageSize,
	totalPages: $state.totalPages,
	resourceType: $state.resourceType
}));

// Derived stores for resource types
export const wordlists = derived(resourceCacheState, ($state) => $state.wordlists);
export const rulelists = derived(resourceCacheState, ($state) => $state.rulelists);
export const masklists = derived(resourceCacheState, ($state) => $state.masklists);
export const charsets = derived(resourceCacheState, ($state) => $state.charsets);
export const dynamicWordlists = derived(resourceCacheState, ($state) => $state.dynamicWordlists);

// Resource store actions
export const resourcesStore = {
	// Basic resource operations
	setResources: (
		resources: ResourceListItem[],
		totalCount: number,
		page: number,
		pageSize: number,
		totalPages: number,
		resourceType: AttackResourceType | null = null
	) => {
		resourceState.update((state) => ({
			...state,
			resources,
			totalCount,
			page,
			pageSize,
			totalPages,
			resourceType,
			loading: false,
			error: null
		}));
	},

	addResource: (resource: ResourceListItem) => {
		resourceState.update((state) => ({
			...state,
			resources: [...state.resources, resource],
			totalCount: state.totalCount + 1
		}));
		// Also update cache if applicable
		resourcesStore.updateResourceCache(resource);
	},

	updateResource: (id: string, updates: Partial<ResourceListItem>) => {
		resourceState.update((state) => ({
			...state,
			resources: state.resources.map((r) => (r.id === id ? { ...r, ...updates } : r))
		}));
		// Also update cache if applicable
		const updatedResource = get(resourceState).resources.find((r) => r.id === id);
		if (updatedResource) {
			resourcesStore.updateResourceCache(updatedResource);
		}
	},

	removeResource: (id: string) => {
		const currentState = get(resourceState);
		const resource = currentState.resources.find((r) => r.id === id);

		resourceState.update((state) => ({
			...state,
			resources: state.resources.filter((r) => r.id !== id),
			totalCount: Math.max(0, state.totalCount - 1)
		}));

		// Clean up associated detail data
		resourceDetailState.update((state) => {
			const { [id]: removedDetail, ...details } = state.details;
			const { [id]: removedPreview, ...previews } = state.previews;
			const { [id]: removedContent, ...content } = state.content;
			const { [id]: removedLines, ...lines } = state.lines;
			const { [id]: removedLoading, ...loading } = state.loading;
			const { [id]: removedErrors, ...errors } = state.errors;
			return { details, previews, content, lines, loading, errors };
		});

		// Also remove from cache if applicable
		if (resource) {
			resourcesStore.removeFromResourceCache(resource);
		}
	},

	setLoading: (loading: boolean) => {
		resourceState.update((state) => ({ ...state, loading }));
	},

	setError: (error: string | null) => {
		resourceState.update((state) => ({ ...state, error }));
	},

	// Resource detail operations
	setResourceDetail: (resourceId: string, detail: ResourceDetailResponse) => {
		resourceDetailState.update((state) => ({
			...state,
			details: { ...state.details, [resourceId]: detail },
			loading: { ...state.loading, [resourceId]: false },
			errors: { ...state.errors, [resourceId]: null }
		}));
	},

	setResourcePreview: (resourceId: string, preview: ResourcePreviewResponse) => {
		resourceDetailState.update((state) => ({
			...state,
			previews: { ...state.previews, [resourceId]: preview },
			loading: { ...state.loading, [resourceId]: false },
			errors: { ...state.errors, [resourceId]: null }
		}));
	},

	setResourceContent: (resourceId: string, content: ResourceContentResponse) => {
		resourceDetailState.update((state) => ({
			...state,
			content: { ...state.content, [resourceId]: content },
			loading: { ...state.loading, [resourceId]: false },
			errors: { ...state.errors, [resourceId]: null }
		}));
	},

	setResourceLines: (resourceId: string, lines: ResourceLinesResponse) => {
		resourceDetailState.update((state) => ({
			...state,
			lines: { ...state.lines, [resourceId]: lines },
			loading: { ...state.loading, [resourceId]: false },
			errors: { ...state.errors, [resourceId]: null }
		}));
	},

	setResourceLoading: (resourceId: string, loading: boolean) => {
		resourceDetailState.update((state) => ({
			...state,
			loading: { ...state.loading, [resourceId]: loading }
		}));
	},

	setResourceError: (resourceId: string, error: string | null) => {
		resourceDetailState.update((state) => ({
			...state,
			errors: { ...state.errors, [resourceId]: error },
			loading: { ...state.loading, [resourceId]: false }
		}));
	},

	// Resource cache operations
	updateResourceCache: (resource: ResourceListItem) => {
		resourceCacheState.update((state) => {
			const newState = { ...state };

			switch (resource.resource_type) {
				case 'word_list':
					newState.wordlists = updateResourceInArray(state.wordlists, resource);
					break;
				case 'rule_list':
					newState.rulelists = updateResourceInArray(state.rulelists, resource);
					break;
				case 'mask_list':
					newState.masklists = updateResourceInArray(state.masklists, resource);
					break;
				case 'charset':
					newState.charsets = updateResourceInArray(state.charsets, resource);
					break;
				case 'dynamic_word_list':
					newState.dynamicWordlists = updateResourceInArray(
						state.dynamicWordlists,
						resource
					);
					break;
			}

			newState.lastUpdated[resource.resource_type] = Date.now();
			return newState;
		});
	},

	removeFromResourceCache: (resource: ResourceListItem) => {
		resourceCacheState.update((state) => {
			const newState = { ...state };

			switch (resource.resource_type) {
				case 'word_list':
					newState.wordlists = state.wordlists.filter((r) => r.id !== resource.id);
					break;
				case 'rule_list':
					newState.rulelists = state.rulelists.filter((r) => r.id !== resource.id);
					break;
				case 'mask_list':
					newState.masklists = state.masklists.filter((r) => r.id !== resource.id);
					break;
				case 'charset':
					newState.charsets = state.charsets.filter((r) => r.id !== resource.id);
					break;
				case 'dynamic_word_list':
					newState.dynamicWordlists = state.dynamicWordlists.filter(
						(r) => r.id !== resource.id
					);
					break;
			}

			return newState;
		});
	},

	setResourceTypeCache: (resourceType: AttackResourceType, resources: ResourceListItem[]) => {
		resourceCacheState.update((state) => {
			const newState = { ...state };

			switch (resourceType) {
				case 'word_list':
					newState.wordlists = resources;
					break;
				case 'rule_list':
					newState.rulelists = resources;
					break;
				case 'mask_list':
					newState.masklists = resources;
					break;
				case 'charset':
					newState.charsets = resources;
					break;
				case 'dynamic_word_list':
					newState.dynamicWordlists = resources;
					break;
			}

			newState.lastUpdated[resourceType] = Date.now();
			newState.loading[resourceType] = false;
			return newState;
		});
	},

	setResourceTypeLoading: (resourceType: AttackResourceType, loading: boolean) => {
		resourceCacheState.update((state) => ({
			...state,
			loading: { ...state.loading, [resourceType]: loading }
		}));
	},

	// Getters
	getResourceDetail: (resourceId: string): ResourceDetailResponse | null => {
		const state = get(resourceDetailState);
		return state.details[resourceId] || null;
	},

	getResourcePreview: (resourceId: string): ResourcePreviewResponse | null => {
		const state = get(resourceDetailState);
		return state.previews[resourceId] || null;
	},

	getResourceContent: (resourceId: string): ResourceContentResponse | null => {
		const state = get(resourceDetailState);
		return state.content[resourceId] || null;
	},

	getResourceLines: (resourceId: string): ResourceLinesResponse | null => {
		const state = get(resourceDetailState);
		return state.lines[resourceId] || null;
	},

	isResourceLoading: (resourceId: string): boolean => {
		const state = get(resourceDetailState);
		return state.loading[resourceId] || false;
	},

	getResourceError: (resourceId: string): string | null => {
		const state = get(resourceDetailState);
		return state.errors[resourceId] || null;
	},

	isResourceTypeLoading: (resourceType: AttackResourceType): boolean => {
		const state = get(resourceCacheState);
		return state.loading[resourceType] || false;
	},

	getResourcesByType: (resourceType: AttackResourceType): ResourceListItem[] => {
		const state = get(resourceCacheState);
		switch (resourceType) {
			case 'word_list':
				return state.wordlists;
			case 'rule_list':
				return state.rulelists;
			case 'mask_list':
				return state.masklists;
			case 'charset':
				return state.charsets;
			case 'dynamic_word_list':
				return state.dynamicWordlists;
			default:
				return [];
		}
	},

	// API operations
	async loadResourcesByType(resourceType: AttackResourceType): Promise<void> {
		if (!browser) return;

		this.setResourceTypeLoading(resourceType, true);

		try {
			const response = await fetch(`/api/v1/web/resources?resource_type=${resourceType}`);

			if (!response.ok) {
				throw new Error(`HTTP ${response.status}`);
			}

			const data = await response.json();
			const resources = data.items || [];

			this.setResourceTypeCache(resourceType, resources);
		} catch (error) {
			console.error(`Failed to load ${resourceType} resources:`, error);
			this.setResourceTypeLoading(resourceType, false);
		}
	},

	async loadAllResourceTypes(): Promise<void> {
		if (!browser) return;

		const resourceTypes: AttackResourceType[] = [
			'word_list',
			'rule_list',
			'mask_list',
			'charset',
			'dynamic_word_list'
		];

		await Promise.all(resourceTypes.map((type) => this.loadResourcesByType(type)));
	},

	// Hydration from SSR data
	hydrateResources(
		resources: ResourceListItem[],
		totalCount: number,
		page: number,
		pageSize: number,
		totalPages: number,
		resourceType: AttackResourceType | null = null
	) {
		this.setResources(resources, totalCount, page, pageSize, totalPages, resourceType);

		// Also update cache with these resources
		resources.forEach((resource) => {
			this.updateResourceCache(resource);
		});
	},

	hydrateResourceDetail(
		resourceId: string,
		detail?: ResourceDetailResponse,
		preview?: ResourcePreviewResponse
	) {
		if (detail) {
			this.setResourceDetail(resourceId, detail);
		}
		if (preview) {
			this.setResourcePreview(resourceId, preview);
		}
	}
};

// Helper function to update resource in array
function updateResourceInArray(
	array: ResourceListItem[],
	resource: ResourceListItem
): ResourceListItem[] {
	const existingIndex = array.findIndex((r) => r.id === resource.id);
	if (existingIndex >= 0) {
		// Update existing resource
		return array.map((r, i) => (i === existingIndex ? resource : r));
	} else {
		// Add new resource
		return [...array, resource];
	}
}

// Derived stores for specific resource details
export function createResourceDetailStore(resourceId: string) {
	return derived(resourceDetailState, ($state) => $state.details[resourceId] || null);
}

export function createResourcePreviewStore(resourceId: string) {
	return derived(resourceDetailState, ($state) => $state.previews[resourceId] || null);
}

export function createResourceContentStore(resourceId: string) {
	return derived(resourceDetailState, ($state) => $state.content[resourceId] || null);
}

export function createResourceLinesStore(resourceId: string) {
	return derived(resourceDetailState, ($state) => $state.lines[resourceId] || null);
}

export function createResourceLoadingStore(resourceId: string) {
	return derived(resourceDetailState, ($state) => $state.loading[resourceId] || false);
}

export function createResourceErrorStore(resourceId: string) {
	return derived(resourceDetailState, ($state) => $state.errors[resourceId] || null);
}

export function createResourceTypeLoadingStore(resourceType: AttackResourceType) {
	return derived(resourceCacheState, ($state) => $state.loading[resourceType] || false);
}
