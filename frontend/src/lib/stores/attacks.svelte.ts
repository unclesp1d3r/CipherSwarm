import { browser } from '$app/environment';
import type { AttackOut, AttackSummary } from '$lib/schemas/attacks';
import type { AttackResourceFileOut } from '$lib/schemas/attacks';

// Use schema types instead of custom interfaces
export type Attack = AttackOut;
export type ResourceFile = AttackResourceFileOut;

// Keep custom interface for AttackPerformance since the schema doesn't match API response
export interface AttackPerformance {
    hashes_done: number;
    hashes_per_sec: number;
    eta: string | number;
    agent_count: number;
    // Additional properties needed by components
    total_hashes?: number;
    progress?: number;
}

export interface AttackEstimate {
    keyspace: number;
    complexity_score: number;
}

// Core state using SvelteKit 5 runes
const attacksState = $state<Attack[]>([]);
const attackPerformanceState = $state<Record<string, AttackPerformance>>({});
const attackLoadingState = $state<Record<string, boolean>>({});
const attackErrorState = $state<Record<string, string | null>>({});

// Resource state
const wordlistsState = $state<ResourceFile[]>([]);
const rulelistsState = $state<ResourceFile[]>([]);
const resourcesLoadingState = $state<{ value: boolean }>({ value: false });

// Estimation state
const attackEstimatesState = $state<Record<string, AttackEstimate>>({});

// Live updates state
const liveUpdatesState = $state<Record<string, boolean>>({});

// Live updates interval
let liveUpdatesInterval: NodeJS.Timeout | null = null;

// Derived stores at module level
const attacks = $derived(attacksState);
const wordlists = $derived(wordlistsState);
const rulelists = $derived(rulelistsState);
const resourcesLoading = $derived(resourcesLoadingState.value);

// Export functions that return the derived values
export function getAttacks() {
    return attacks;
}

export function getWordlists() {
    return wordlists;
}

export function getRulelists() {
    return rulelists;
}

export function getResourcesLoading() {
    return resourcesLoading;
}

// Attack store actions
export const attacksStore = {
    // Getters for reactive state
    get attacks() {
        return attacksState;
    },
    get wordlists() {
        return wordlistsState;
    },
    get rulelists() {
        return rulelistsState;
    },
    get resourcesLoading() {
        return resourcesLoadingState.value;
    },

    // Basic attack operations
    setAttacks: (attacks: Attack[]) => {
        attacksState.splice(0, attacksState.length, ...attacks);
    },
    addAttack: (attack: Attack) => {
        attacksState.push(attack);
    },
    updateAttackInStore: (id: number, updates: Partial<Attack>) => {
        const index = attacksState.findIndex((attack) => attack.id === id);
        if (index !== -1) {
            attacksState[index] = { ...attacksState[index], ...updates };
        }
    },
    removeAttack: (id: number) => {
        const index = attacksState.findIndex((attack) => attack.id === id);
        if (index !== -1) {
            attacksState.splice(index, 1);
        }
    },

    // Performance operations
    setAttackPerformance: (attackId: string, performance: AttackPerformance) => {
        attackPerformanceState[attackId] = performance;
    },
    setAttackLoading: (attackId: string, loading: boolean) => {
        attackLoadingState[attackId] = loading;
    },
    setAttackError: (attackId: string, error: string | null) => {
        attackErrorState[attackId] = error;
    },

    // Resource operations
    setWordlists: (wordlists: ResourceFile[]) => {
        wordlistsState.splice(0, wordlistsState.length, ...wordlists);
    },
    setRulelists: (rulelists: ResourceFile[]) => {
        rulelistsState.splice(0, rulelistsState.length, ...rulelists);
    },
    setResourcesLoading: (loading: boolean) => {
        resourcesLoadingState.value = loading;
    },

    // Estimation operations
    setAttackEstimate: (key: string, estimate: AttackEstimate) => {
        attackEstimatesState[key] = estimate;
    },

    // Live updates operations
    setLiveUpdates: (attackId: string, enabled: boolean) => {
        liveUpdatesState[attackId] = enabled;
    },

    // API operations
    async loadAttackPerformance(attackId: string) {
        if (!browser) return;

        attacksStore.setAttackLoading(attackId, true);
        attacksStore.setAttackError(attackId, null);

        try {
            const response = await fetch(`/api/v1/web/attacks/${attackId}/performance`);

            if (response.status === 404) {
                // No performance data available yet - this is normal
                attacksStore.setAttackError(attackId, null);
                return;
            }

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();
            const performance: AttackPerformance = {
                hashes_done: data.hashes_done || 0,
                hashes_per_sec: data.hashes_per_sec || 0,
                eta: data.eta || 'Unknown',
                agent_count: data.agent_count || 0,
                total_hashes: data.total_hashes || 0,
                progress: data.progress || 0,
            };

            attacksStore.setAttackPerformance(attackId, performance);
        } catch (error) {
            console.error(`Failed to load attack performance for ${attackId}:`, error);
            attacksStore.setAttackError(attackId, 'Failed to load performance data');
        } finally {
            attacksStore.setAttackLoading(attackId, false);
        }
    },

    async loadResources() {
        if (!browser) return;

        attacksStore.setResourcesLoading(true);

        try {
            const [wordlistResponse, rulelistResponse] = await Promise.all([
                fetch('/api/v1/web/resources?type=word_list'),
                fetch('/api/v1/web/resources?type=rule_list'),
            ]);

            if (wordlistResponse.ok) {
                const wordlistData = await wordlistResponse.json();
                attacksStore.setWordlists(wordlistData.resources || []);
            }

            if (rulelistResponse.ok) {
                const rulelistData = await rulelistResponse.json();
                attacksStore.setRulelists(rulelistData.resources || []);
            }
        } catch (error) {
            console.error('Failed to load resources:', error);
        } finally {
            attacksStore.setResourcesLoading(false);
        }
    },

    async estimateAttack(payload: Record<string, unknown>) {
        if (!browser) return null;

        try {
            const response = await fetch('/api/v1/web/attacks/estimate', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(payload),
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();
            return data;
        } catch (error) {
            console.error('Failed to estimate attack:', error);
            return null;
        }
    },

    async createAttack(payload: Record<string, unknown>) {
        if (!browser) return null;

        try {
            const response = await fetch('/api/v1/web/attacks', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(payload),
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();
            return data;
        } catch (error) {
            console.error('Failed to create attack:', error);
            throw error;
        }
    },

    async updateAttack(attackId: number, payload: Record<string, unknown>) {
        if (!browser) return null;

        try {
            const response = await fetch(`/api/v1/web/attacks/${attackId}`, {
                method: 'PUT',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify(payload),
            });

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}`);
            }

            const data = await response.json();
            return data;
        } catch (error) {
            console.error('Failed to update attack:', error);
            throw error;
        }
    },

    async toggleLiveUpdates(attackId: string, enabled: boolean) {
        attacksStore.setLiveUpdates(attackId, enabled);

        if (enabled) {
            // Load initial data
            await attacksStore.loadAttackPerformance(attackId);
        }
    },

    enableLiveUpdates() {
        if (liveUpdatesInterval) return;

        liveUpdatesInterval = setInterval(async () => {
            const enabledAttacks = Object.entries(liveUpdatesState)
                .filter(([, enabled]) => enabled)
                .map(([attackId]) => attackId);

            for (const attackId of enabledAttacks) {
                await attacksStore.loadAttackPerformance(attackId);
            }
        }, 5000); // Update every 5 seconds
    },

    disableLiveUpdates() {
        if (liveUpdatesInterval) {
            clearInterval(liveUpdatesInterval);
            liveUpdatesInterval = null;
        }

        // Clear all live update flags
        Object.keys(liveUpdatesState).forEach((attackId) => {
            liveUpdatesState[attackId] = false;
        });
    },
};
