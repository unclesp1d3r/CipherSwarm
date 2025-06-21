import { browser } from '$app/environment';
import type {
    ResourceListItem,
    ResourceDetailResponse,
    ResourcePreviewResponse,
    ResourceContentResponse,
    ResourceLinesResponse,
    AttackResourceType,
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

// Create reactive state using SvelteKit 5 runes
const resourceState = $state<ResourceState>({
    resources: [],
    loading: false,
    error: null,
    totalCount: 0,
    page: 1,
    pageSize: 25,
    totalPages: 0,
    resourceType: null,
});

const resourceDetailState = $state<ResourceDetailState>({
    details: {},
    previews: {},
    content: {},
    lines: {},
    loading: {},
    errors: {},
});

const resourceCacheState = $state<ResourceCacheState>({
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
        dynamic_word_list: 0,
    },
    loading: {
        word_list: false,
        rule_list: false,
        mask_list: false,
        charset: false,
        dynamic_word_list: false,
    },
});

// Derived stores at module level
const resources = $derived(resourceState.resources);
const resourcesLoading = $derived(resourceState.loading);
const resourcesError = $derived(resourceState.error);
const resourcesPagination = $derived({
    totalCount: resourceState.totalCount,
    page: resourceState.page,
    pageSize: resourceState.pageSize,
    totalPages: resourceState.totalPages,
    resourceType: resourceState.resourceType,
});

// Derived stores for resource types
const wordlists = $derived(resourceCacheState.wordlists);
const rulelists = $derived(resourceCacheState.rulelists);
const masklists = $derived(resourceCacheState.masklists);
const charsets = $derived(resourceCacheState.charsets);
const dynamicWordlists = $derived(resourceCacheState.dynamicWordlists);

// Export functions that return the derived values
export function getResources() {
    return resources;
}

export function getResourcesLoading() {
    return resourcesLoading;
}

export function getResourcesError() {
    return resourcesError;
}

export function getResourcesPagination() {
    return resourcesPagination;
}

export function getWordlists() {
    return wordlists;
}

export function getRulelists() {
    return rulelists;
}

export function getMasklists() {
    return masklists;
}

export function getCharsets() {
    return charsets;
}

export function getDynamicWordlists() {
    return dynamicWordlists;
}

// Resource store actions
export const resourcesStore = {
    // Getters for reactive state
    get resources() {
        return resourceState.resources;
    },
    get loading() {
        return resourceState.loading;
    },
    get error() {
        return resourceState.error;
    },
    get pagination() {
        return {
            totalCount: resourceState.totalCount,
            page: resourceState.page,
            pageSize: resourceState.pageSize,
            totalPages: resourceState.totalPages,
            resourceType: resourceState.resourceType,
        };
    },
    get wordlists() {
        return resourceCacheState.wordlists;
    },
    get rulelists() {
        return resourceCacheState.rulelists;
    },
    get masklists() {
        return resourceCacheState.masklists;
    },
    get charsets() {
        return resourceCacheState.charsets;
    },
    get dynamicWordlists() {
        return resourceCacheState.dynamicWordlists;
    },

    // Basic resource operations
    setResources: (
        resources: ResourceListItem[],
        totalCount: number,
        page: number,
        pageSize: number,
        totalPages: number,
        resourceType: AttackResourceType | null = null
    ) => {
        resourceState.resources = resources;
        resourceState.totalCount = totalCount;
        resourceState.page = page;
        resourceState.pageSize = pageSize;
        resourceState.totalPages = totalPages;
        resourceState.resourceType = resourceType;
        resourceState.loading = false;
        resourceState.error = null;
    },

    addResource: (resource: ResourceListItem) => {
        resourceState.resources = [...resourceState.resources, resource];
        resourceState.totalCount = resourceState.totalCount + 1;
        // Also update cache if applicable
        resourcesStore.updateResourceCache(resource);
    },

    updateResource: (id: string, updates: Partial<ResourceListItem>) => {
        resourceState.resources = resourceState.resources.map((r) =>
            r.id === id ? { ...r, ...updates } : r
        );
        // Also update cache if applicable
        const updatedResource = resourceState.resources.find((r) => r.id === id);
        if (updatedResource) {
            resourcesStore.updateResourceCache(updatedResource);
        }
    },

    removeResource: (id: string) => {
        const resource = resourceState.resources.find((r) => r.id === id);

        resourceState.resources = resourceState.resources.filter((r) => r.id !== id);
        resourceState.totalCount = Math.max(0, resourceState.totalCount - 1);

        // Clean up associated detail data
        delete resourceDetailState.details[id];
        delete resourceDetailState.previews[id];
        delete resourceDetailState.content[id];
        delete resourceDetailState.lines[id];
        delete resourceDetailState.loading[id];
        delete resourceDetailState.errors[id];

        // Also remove from cache if applicable
        if (resource) {
            resourcesStore.removeFromResourceCache(resource);
        }
    },

    setLoading: (loading: boolean) => {
        resourceState.loading = loading;
    },

    setError: (error: string | null) => {
        resourceState.error = error;
    },

    // Resource detail operations
    setResourceDetail: (resourceId: string, detail: ResourceDetailResponse) => {
        resourceDetailState.details[resourceId] = detail;
        resourceDetailState.loading[resourceId] = false;
        resourceDetailState.errors[resourceId] = null;
    },

    setResourcePreview: (resourceId: string, preview: ResourcePreviewResponse) => {
        resourceDetailState.previews[resourceId] = preview;
        resourceDetailState.loading[resourceId] = false;
        resourceDetailState.errors[resourceId] = null;
    },

    setResourceContent: (resourceId: string, content: ResourceContentResponse) => {
        resourceDetailState.content[resourceId] = content;
        resourceDetailState.loading[resourceId] = false;
        resourceDetailState.errors[resourceId] = null;
    },

    setResourceLines: (resourceId: string, lines: ResourceLinesResponse) => {
        resourceDetailState.lines[resourceId] = lines;
        resourceDetailState.loading[resourceId] = false;
        resourceDetailState.errors[resourceId] = null;
    },

    setResourceLoading: (resourceId: string, loading: boolean) => {
        resourceDetailState.loading[resourceId] = loading;
    },

    setResourceError: (resourceId: string, error: string | null) => {
        resourceDetailState.errors[resourceId] = error;
        resourceDetailState.loading[resourceId] = false;
    },

    // Resource cache operations
    updateResourceCache: (resource: ResourceListItem) => {
        const updateArray = (
            array: ResourceListItem[],
            newResource: ResourceListItem
        ): ResourceListItem[] => {
            const existingIndex = array.findIndex((r) => r.id === newResource.id);
            if (existingIndex >= 0) {
                const newArray = [...array];
                newArray[existingIndex] = newResource;
                return newArray;
            } else {
                return [...array, newResource];
            }
        };

        switch (resource.resource_type) {
            case 'word_list':
                resourceCacheState.wordlists = updateArray(resourceCacheState.wordlists, resource);
                break;
            case 'rule_list':
                resourceCacheState.rulelists = updateArray(resourceCacheState.rulelists, resource);
                break;
            case 'mask_list':
                resourceCacheState.masklists = updateArray(resourceCacheState.masklists, resource);
                break;
            case 'charset':
                resourceCacheState.charsets = updateArray(resourceCacheState.charsets, resource);
                break;
            case 'dynamic_word_list':
                resourceCacheState.dynamicWordlists = updateArray(
                    resourceCacheState.dynamicWordlists,
                    resource
                );
                break;
        }
    },

    removeFromResourceCache: (resource: ResourceListItem) => {
        switch (resource.resource_type) {
            case 'word_list':
                resourceCacheState.wordlists = resourceCacheState.wordlists.filter(
                    (r) => r.id !== resource.id
                );
                break;
            case 'rule_list':
                resourceCacheState.rulelists = resourceCacheState.rulelists.filter(
                    (r) => r.id !== resource.id
                );
                break;
            case 'mask_list':
                resourceCacheState.masklists = resourceCacheState.masklists.filter(
                    (r) => r.id !== resource.id
                );
                break;
            case 'charset':
                resourceCacheState.charsets = resourceCacheState.charsets.filter(
                    (r) => r.id !== resource.id
                );
                break;
            case 'dynamic_word_list':
                resourceCacheState.dynamicWordlists = resourceCacheState.dynamicWordlists.filter(
                    (r) => r.id !== resource.id
                );
                break;
        }
    },

    setResourceTypeLoading: (resourceType: AttackResourceType, loading: boolean) => {
        resourceCacheState.loading[resourceType] = loading;
    },

    setResourceTypeData: (resourceType: AttackResourceType, resources: ResourceListItem[]) => {
        switch (resourceType) {
            case 'word_list':
                resourceCacheState.wordlists = resources;
                break;
            case 'rule_list':
                resourceCacheState.rulelists = resources;
                break;
            case 'mask_list':
                resourceCacheState.masklists = resources;
                break;
            case 'charset':
                resourceCacheState.charsets = resources;
                break;
            case 'dynamic_word_list':
                resourceCacheState.dynamicWordlists = resources;
                break;
        }
        resourceCacheState.lastUpdated[resourceType] = Date.now();
        resourceCacheState.loading[resourceType] = false;
    },

    // API operations
    async loadResourceDetail(resourceId: string): Promise<void> {
        if (!browser) return;

        resourcesStore.setResourceLoading(resourceId, true);

        try {
            const response = await fetch(`/api/v1/web/resources/${resourceId}`);

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const detail = await response.json();
            resourcesStore.setResourceDetail(resourceId, detail);
        } catch (error) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown error';
            resourcesStore.setResourceError(resourceId, errorMessage);
        }
    },

    async loadResourcePreview(resourceId: string): Promise<void> {
        if (!browser) return;

        resourcesStore.setResourceLoading(resourceId, true);

        try {
            const response = await fetch(`/api/v1/web/resources/${resourceId}/preview`);

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const preview = await response.json();
            resourcesStore.setResourcePreview(resourceId, preview);
        } catch (error) {
            const errorMessage = error instanceof Error ? error.message : 'Unknown error';
            resourcesStore.setResourceError(resourceId, errorMessage);
        }
    },

    async loadResourcesByType(resourceType: AttackResourceType): Promise<void> {
        if (!browser) return;

        resourcesStore.setResourceTypeLoading(resourceType, true);

        try {
            const response = await fetch(`/api/v1/web/resources?type=${resourceType}`);

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();
            resourcesStore.setResourceTypeData(resourceType, data.resources || []);
        } catch (error) {
            console.error(`Failed to load ${resourceType} resources:`, error);
            resourcesStore.setResourceTypeLoading(resourceType, false);
        }
    },

    async loadAllResourceTypes(): Promise<void> {
        if (!browser) return;

        const resourceTypes: AttackResourceType[] = [
            'word_list',
            'rule_list',
            'mask_list',
            'charset',
            'dynamic_word_list',
        ];

        await Promise.all(resourceTypes.map((type) => resourcesStore.loadResourcesByType(type)));
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
        resourcesStore.setResources(
            resources,
            totalCount,
            page,
            pageSize,
            totalPages,
            resourceType
        );

        // Also update cache
        resources.forEach((resource) => {
            resourcesStore.updateResourceCache(resource);
        });
    },

    hydrateResourceDetail(
        resourceId: string,
        detail?: ResourceDetailResponse,
        preview?: ResourcePreviewResponse
    ) {
        if (detail) {
            resourcesStore.setResourceDetail(resourceId, detail);
        }
        if (preview) {
            resourcesStore.setResourcePreview(resourceId, preview);
        }
    },
};
