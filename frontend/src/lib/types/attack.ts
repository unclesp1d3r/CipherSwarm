import type { AttackOut, AttackSummary } from '$lib/schemas/attacks';
import type { AttackState, AttackMode } from '$lib/schemas/base';

// Re-export schema types
export type { AttackOut, AttackSummary };

// Legacy type aliases
export type Attack = AttackOut;
export type AttackRead = AttackOut;
export type AttackBasic = AttackSummary;

// Create/Update types for forms (these would be derived from the schema)
export interface AttackCreate {
    name: string;
    description?: string;
    attack_mode: AttackMode;
    hash_mode: number;
    mask?: string;
    increment_mode: boolean;
    increment_minimum: number;
    increment_maximum: number;
    optimized: boolean;
    slow_candidate_generators: boolean;
    workload_profile: number;
    disable_markov: boolean;
    classic_markov: boolean;
    markov_threshold: number;
    left_rule?: string;
    right_rule?: string;
    custom_charset_1?: string;
    custom_charset_2?: string;
    custom_charset_3?: string;
    custom_charset_4?: string;
    hash_list_id: number;
    priority: number;
    position: number;
    campaign_id?: number;
    template_id?: number;
    modifiers?: string[];
}

export interface AttackUpdate {
    name?: string;
    description?: string;
    priority?: number;
    position?: number;
    modifiers?: string[];
}

// Response types for listings
export interface AttacksResponse {
    items: AttackOut[];
    total: number;
    limit: number;
    offset: number;
    search?: string;
}

// Schema for validating the response
export const AttacksResponseSchema = {
    items: [] as AttackOut[],
    total: 0,
    limit: 10,
    offset: 0,
    search: undefined as string | undefined,
};

// Helper functions for display
export function getAttackTypeBadge(attackMode: AttackMode): { variant: string; label: string } {
    switch (attackMode) {
        case 'dictionary':
            return { variant: 'default', label: 'Dictionary' };
        case 'mask':
            return { variant: 'secondary', label: 'Mask' };
        case 'hybrid_dictionary':
            return { variant: 'outline', label: 'Hybrid Dict' };
        case 'hybrid_mask':
            return { variant: 'outline', label: 'Hybrid Mask' };
        default:
            return { variant: 'default', label: 'Unknown' };
    }
}

export function getAttackStateBadge(state: AttackState): { variant: string; label: string } {
    switch (state) {
        case 'draft':
            return { variant: 'outline', label: 'Draft' };
        case 'pending':
            return { variant: 'secondary', label: 'Pending' };
        case 'running':
            return { variant: 'default', label: 'Running' };
        case 'completed':
            return { variant: 'success', label: 'Completed' };
        case 'failed':
            return { variant: 'destructive', label: 'Failed' };
        case 'abandoned':
            return { variant: 'outline', label: 'Abandoned' };
        default:
            return { variant: 'default', label: 'Unknown' };
    }
}

export function formatLength(length: number | null | undefined): string {
    if (length == null) return 'N/A';
    return length.toString();
}

export function formatKeyspace(keyspace: number | null | undefined): string {
    if (keyspace == null) return 'N/A';

    if (keyspace >= 1e12) {
        return `${(keyspace / 1e12).toFixed(1)}T`;
    } else if (keyspace >= 1e9) {
        return `${(keyspace / 1e9).toFixed(1)}B`;
    } else if (keyspace >= 1e6) {
        return `${(keyspace / 1e6).toFixed(1)}M`;
    } else if (keyspace >= 1e3) {
        return `${(keyspace / 1e3).toFixed(1)}K`;
    }
    return keyspace.toString();
}
