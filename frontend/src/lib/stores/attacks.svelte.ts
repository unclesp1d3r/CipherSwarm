import { browser } from '$app/environment';

export interface Attack {
    id?: number;
    attack_mode?: string | null;
    name?: string | null;
    comment?: string | null;
    language?: string | null;
    mask?: string | null;
    min_length?: number | null;
    max_length?: number | null;
    wordlist_source?: string | null;
    word_list_id?: string | null;
    rule_list_id?: string | null;
    modifiers?: string[] | null;
    custom_charset_1?: string | null;
    custom_charset_2?: string | null;
    custom_charset_3?: string | null;
    custom_charset_4?: string | null;
    charset_lowercase?: boolean | null;
    charset_uppercase?: boolean | null;
    charset_digits?: boolean | null;
    charset_special?: boolean | null;
    increment_minimum?: number | null;
    increment_maximum?: number | null;
    masks_inline?: string[] | null;
    wordlist_inline?: string[] | null;
    type?: string | null;
    complexity_score?: number | null;
    keyspace?: number | null;
    state?: string | null;
    created_at?: string | null;
    updated_at?: string | null;
    campaign_id?: number | null;
    campaign_name?: string | null;
    hash_type_id?: number | null;
    word_list_name?: string | null;
    rule_list_name?: string | null;
}

export interface AttackPerformance {
    hashes_done: number;
    hashes_per_sec: number;
    eta: string | number;
    agent_count: number;
    // Additional properties needed by components
    total_hashes?: number;
    progress?: number;
}

export interface ResourceFile {
    id: string;
    name: string;
    type: string;
    file_size?: number;
    description?: string;
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

// Store actions
export const attacksActions = {
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

        attacksActions.setAttackLoading(attackId, true);
        attacksActions.setAttackError(attackId, null);

        try {
            const response = await fetch(`/api/v1/web/attacks/${attackId}/performance`);

            if (response.status === 404) {
                // No performance data available yet - this is normal
                attacksActions.setAttackError(attackId, null);
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

            attacksActions.setAttackPerformance(attackId, performance);
        } catch (error) {
            console.error(`Failed to load attack performance for ${attackId}:`, error);
            attacksActions.setAttackError(attackId, 'Failed to load performance data');
        } finally {
            attacksActions.setAttackLoading(attackId, false);
        }
    },

    async loadResources() {
        if (!browser) return;

        attacksActions.setResourcesLoading(true);

        try {
            const [wordlistResponse, rulelistResponse] = await Promise.all([
                fetch('/api/v1/web/resources?type=word_list'),
                fetch('/api/v1/web/resources?type=rule_list'),
            ]);

            if (wordlistResponse.ok) {
                const wordlistData = await wordlistResponse.json();
                attacksActions.setWordlists(wordlistData.resources || []);
            }

            if (rulelistResponse.ok) {
                const rulelistData = await rulelistResponse.json();
                attacksActions.setRulelists(rulelistData.resources || []);
            }
        } catch (error) {
            console.error('Failed to load resources:', error);
        } finally {
            attacksActions.setResourcesLoading(false);
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
        attacksActions.setLiveUpdates(attackId, enabled);

        if (enabled) {
            // Load initial data
            await attacksActions.loadAttackPerformance(attackId);
        }
    },

    enableLiveUpdates() {
        if (liveUpdatesInterval) return;

        liveUpdatesInterval = setInterval(async () => {
            const enabledAttacks = Object.entries(liveUpdatesState)
                .filter(([, enabled]) => enabled)
                .map(([attackId]) => attackId);

            for (const attackId of enabledAttacks) {
                await attacksActions.loadAttackPerformance(attackId);
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
