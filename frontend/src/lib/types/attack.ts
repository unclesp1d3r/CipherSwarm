import { z } from 'zod';

// Attack type enum based on backend API
export const AttackTypeSchema = z.enum([
    'dictionary',
    'mask',
    'brute_force',
    'hybrid_dictionary',
    'hybrid_mask'
]);

// Attack state enum based on backend API
export const AttackStateSchema = z.enum([
    'pending',
    'running',
    'completed',
    'error',
    'paused',
    'draft',
    'abandoned'
]);

// Individual attack schema
export const AttackSchema = z.object({
    id: z.number(),
    name: z.string(),
    type: AttackTypeSchema.optional(),
    attack_mode: AttackTypeSchema.optional(), // Backend uses both 'type' and 'attack_mode'
    language: z.string().nullable().optional(),
    length_min: z.number().nullable().optional(),
    length_max: z.number().nullable().optional(),
    min_length: z.number().nullable().optional(), // Backend uses both naming conventions
    max_length: z.number().nullable().optional(),
    settings_summary: z.string().nullable().optional(),
    keyspace: z.number().nullable().optional(),
    complexity_score: z.number().nullable().optional(),
    comment: z.string().nullable().optional(),
    state: AttackStateSchema,
    created_at: z.string(),
    updated_at: z.string(),
    campaign_id: z.number().nullable().optional(),
    campaign_name: z.string().nullable().optional()
});

// Paginated attacks response schema
export const AttacksResponseSchema = z.object({
    items: z.array(AttackSchema),
    total: z.number(),
    page: z.number(),
    size: z.number(),
    total_pages: z.number(),
    q: z.string().nullable().optional()
});

// Type exports
export type AttackType = z.infer<typeof AttackTypeSchema>;
export type AttackState = z.infer<typeof AttackStateSchema>;
export type Attack = z.infer<typeof AttackSchema>;
export type AttacksResponse = z.infer<typeof AttacksResponseSchema>;

// Attack badge configuration
export interface AttackTypeBadge {
    color: string;
    label: string;
}

export interface AttackStateBadge {
    color: string;
    label: string;
}

// Helper functions for badge styling
export function getAttackTypeBadge(type: string): AttackTypeBadge {
    switch (type) {
        case 'dictionary':
            return { color: 'bg-blue-500 text-white', label: 'Dictionary' };
        case 'mask':
            return { color: 'bg-purple-500 text-white', label: 'Mask' };
        case 'brute_force':
            return { color: 'bg-orange-500 text-white', label: 'Brute Force' };
        case 'hybrid_dictionary':
            return { color: 'bg-teal-500 text-white', label: 'Hybrid Dictionary' };
        case 'hybrid_mask':
            return { color: 'bg-pink-500 text-white', label: 'Hybrid Mask' };
        default:
            return {
                color: 'bg-gray-400 text-white',
                label: type.replace('_', ' ').toUpperCase()
            };
    }
}

export function getAttackStateBadge(state: string): AttackStateBadge {
    switch (state) {
        case 'running':
            return { color: 'bg-green-600 text-white', label: 'Running' };
        case 'completed':
            return { color: 'bg-blue-600 text-white', label: 'Completed' };
        case 'error':
            return { color: 'bg-red-600 text-white', label: 'Error' };
        case 'paused':
            return { color: 'bg-yellow-500 text-white', label: 'Paused' };
        case 'draft':
            return { color: 'bg-gray-400 text-white', label: 'Draft' };
        case 'pending':
            return { color: 'bg-gray-500 text-white', label: 'Pending' };
        case 'abandoned':
            return { color: 'bg-gray-300 text-gray-700', label: 'Abandoned' };
        default:
            return {
                color: 'bg-gray-200 text-gray-800',
                label: state.replace('_', ' ').toUpperCase()
            };
    }
}

// Helper functions for formatting
export function formatLength(minLength?: number | null, maxLength?: number | null): string {
    if (minLength === undefined && maxLength === undefined) return '—';
    if (minLength === null && maxLength === null) return '—';
    if (minLength === maxLength) return String(minLength);
    return `${minLength || 0} → ${maxLength || 0}`;
}

export function formatKeyspace(keyspace?: number | null): string {
    if (!keyspace) return '—';
    return keyspace.toLocaleString();
}

export function renderComplexityDots(score?: number | null): { filled: number; total: number } {
    const complexityScore = score || 0;
    return { filled: complexityScore, total: 5 };
}
