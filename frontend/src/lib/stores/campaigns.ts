import { writable } from 'svelte/store';
import type { Campaign } from '$lib/types/campaign';

export const campaigns = writable<Campaign[]>([]);
