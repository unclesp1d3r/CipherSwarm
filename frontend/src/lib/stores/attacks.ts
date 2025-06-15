import { writable, derived, get } from 'svelte/store';
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

// Core stores
const attacksStore = writable<Attack[]>([]);
const attackPerformanceStore = writable<Record<string, AttackPerformance>>({});
const attackLoadingStore = writable<Record<string, boolean>>({});
const attackErrorStore = writable<Record<string, string | null>>({});

// Resource stores
const wordlistsStore = writable<ResourceFile[]>([]);
const rulelistsStore = writable<ResourceFile[]>([]);
const resourcesLoadingStore = writable<boolean>(false);

// Estimation store
const attackEstimatesStore = writable<Record<string, AttackEstimate>>({});

// Live updates store
const liveUpdatesStore = writable<Record<string, boolean>>({});

// Live updates interval
let liveUpdatesInterval: NodeJS.Timeout | null = null;

// Store actions
export const attacksActions = {
	// Basic attack operations
	setAttacks: (attacks: Attack[]) => attacksStore.set(attacks),
	addAttack: (attack: Attack) => {
		attacksStore.update((attacks) => [...attacks, attack]);
	},
	updateAttackInStore: (id: number, updates: Partial<Attack>) => {
		attacksStore.update((attacks) =>
			attacks.map((attack) => (attack.id === id ? { ...attack, ...updates } : attack))
		);
	},
	removeAttack: (id: number) => {
		attacksStore.update((attacks) => attacks.filter((attack) => attack.id !== id));
	},

	// Performance operations
	setAttackPerformance: (attackId: string, performance: AttackPerformance) => {
		attackPerformanceStore.update((store) => ({ ...store, [attackId]: performance }));
	},
	setAttackLoading: (attackId: string, loading: boolean) => {
		attackLoadingStore.update((store) => ({ ...store, [attackId]: loading }));
	},
	setAttackError: (attackId: string, error: string | null) => {
		attackErrorStore.update((store) => ({ ...store, [attackId]: error }));
	},

	// Resource operations
	setWordlists: (wordlists: ResourceFile[]) => wordlistsStore.set(wordlists),
	setRulelists: (rulelists: ResourceFile[]) => rulelistsStore.set(rulelists),
	setResourcesLoading: (loading: boolean) => resourcesLoadingStore.set(loading),

	// Estimation operations
	setAttackEstimate: (key: string, estimate: AttackEstimate) => {
		attackEstimatesStore.update((store) => ({ ...store, [key]: estimate }));
	},

	// Live updates operations
	setLiveUpdates: (attackId: string, enabled: boolean) => {
		liveUpdatesStore.update((store) => ({ ...store, [attackId]: enabled }));
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
				progress: data.progress || 0
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
				fetch('/api/v1/web/resources?type=rule_list')
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
					'Content-Type': 'application/json'
				},
				body: JSON.stringify(payload)
			});

			if (!response.ok) {
				throw new Error(`HTTP ${response.status}`);
			}

			const estimate = await response.json();
			const key = JSON.stringify(payload);
			attacksActions.setAttackEstimate(key, estimate);
			return estimate;
		} catch (error) {
			console.error('Failed to estimate attack:', error);
			return null;
		}
	},

	async createAttack(payload: Record<string, unknown>) {
		if (!browser) return null;

		try {
			const response = await fetch('/api/v1/web/attacks/', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify(payload)
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(JSON.stringify(errorData));
			}

			const attack = await response.json();
			attacksActions.addAttack(attack);
			return attack;
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
					'Content-Type': 'application/json'
				},
				body: JSON.stringify(payload)
			});

			if (!response.ok) {
				const errorData = await response.json();
				throw new Error(JSON.stringify(errorData));
			}

			const attack = await response.json();
			attacksActions.updateAttackInStore(attackId, attack);
			return attack;
		} catch (error) {
			console.error('Failed to update attack:', error);
			throw error;
		}
	},

	async toggleLiveUpdates(attackId: string, enabled: boolean) {
		if (!browser) return false;

		try {
			const response = await fetch(`/api/v1/web/attacks/${attackId}/disable_live_updates`, {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json'
				},
				body: JSON.stringify({ enabled })
			});

			if (!response.ok) {
				throw new Error(`HTTP ${response.status}`);
			}

			attacksActions.setLiveUpdates(attackId, enabled);
			return true;
		} catch (error) {
			console.error('Failed to toggle live updates:', error);
			return false;
		}
	},

	// Real-time updates
	enableLiveUpdates() {
		if (!browser || liveUpdatesInterval) return;

		liveUpdatesInterval = setInterval(() => {
			const liveUpdates = get(liveUpdatesStore);
			Object.keys(liveUpdates).forEach((attackId) => {
				if (liveUpdates[attackId]) {
					attacksActions.loadAttackPerformance(attackId);
				}
			});
		}, 5000); // Update every 5 seconds
	},

	disableLiveUpdates() {
		if (liveUpdatesInterval) {
			clearInterval(liveUpdatesInterval);
			liveUpdatesInterval = null;
		}
	}
};

// Export the store for components that need direct access
export { attacksStore };

// Derived stores
export const attacks = derived(attacksStore, ($attacks) => $attacks);

// Store factory functions for component-specific derived stores
export function createAttackPerformanceStore(attackId: string) {
	return derived(attackPerformanceStore, ($performance) => $performance[attackId] || null);
}

export function createAttackLoadingStore(attackId: string) {
	return derived(attackLoadingStore, ($loading) => $loading[attackId] || false);
}

export function createAttackErrorStore(attackId: string) {
	return derived(attackErrorStore, ($errors) => $errors[attackId] || null);
}

export function createAttackEstimateStore(key: string) {
	return derived(attackEstimatesStore, ($estimates) => $estimates[key] || null);
}

export function createLiveUpdatesStore(attackId: string) {
	return derived(liveUpdatesStore, ($liveUpdates) => $liveUpdates[attackId] || false);
}

// Resource stores
export const wordlists = derived(wordlistsStore, ($wordlists) => $wordlists);
export const rulelists = derived(rulelistsStore, ($rulelists) => $rulelists);
export const resourcesLoading = derived(resourcesLoadingStore, ($loading) => $loading);

// Cleanup on page unload
if (browser) {
	window.addEventListener('beforeunload', () => {
		attacksActions.disableLiveUpdates();
	});
}
