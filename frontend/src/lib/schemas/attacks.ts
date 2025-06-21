/**
 * Attack schemas for CipherSwarm
 * Used by /api/v1/web/attacks/* endpoints
 * Based on authoritative backend API schema
 */

import { z } from 'zod';
import { AttackMode, AttackState, AttackMoveDirection } from './base';
import { AttackResourceFileOut } from './resources';

// Core attack schemas
/**
 * Attack summary schema
 * Attack information with basic configuration details
 */
export const AttackSummary = z.object({
    id: z.number().int().describe('Attack ID'),
    name: z.string().describe('Attack name'),
    attack_mode: AttackMode.describe('Attack mode'),
    type_label: z.string().describe('Human-readable attack type label'),
    length: z.number().int().optional().describe('Attack length parameter'),
    settings_summary: z.string().describe('Summary of attack settings'),
    keyspace: z.number().int().optional().describe('Total keyspace size'),
    complexity_score: z.number().int().optional().describe('Attack complexity score'),
    comment: z.string().optional().describe('Attack comment'),
});
export type AttackSummary = z.infer<typeof AttackSummary>;

/**
 * Attack output schema
 * Complete attack information including all configuration details
 */
export const AttackOut = z.object({
    id: z.number().int().describe('Attack ID'),
    name: z.string().describe('Attack name'),
    description: z.string().optional().describe('Attack description'),
    state: AttackState.describe('Current attack state'),
    attack_mode: AttackMode.describe('Attack mode'),
    attack_mode_hashcat: z.number().int().describe('Hashcat attack mode number'),
    hash_mode: z.number().int().describe('Hash mode'),
    mask: z.string().optional().describe('Mask pattern'),
    increment_mode: z.boolean().describe('Increment mode enabled'),
    increment_minimum: z.number().int().describe('Minimum increment length'),
    increment_maximum: z.number().int().describe('Maximum increment length'),
    optimized: z.boolean().describe('Optimized kernel enabled'),
    slow_candidate_generators: z.boolean().describe('Slow candidate generators enabled'),
    workload_profile: z.number().int().describe('Workload profile'),
    disable_markov: z.boolean().describe('Disable Markov mode'),
    classic_markov: z.boolean().describe('Classic Markov mode'),
    markov_threshold: z.number().int().describe('Markov threshold'),
    left_rule: z.string().optional().describe('Left-hand rule for combinator attacks'),
    right_rule: z.string().optional().describe('Right-hand rule for combinator attacks'),
    custom_charset_1: z.string().optional().describe('Custom charset 1'),
    custom_charset_2: z.string().optional().describe('Custom charset 2'),
    custom_charset_3: z.string().optional().describe('Custom charset 3'),
    custom_charset_4: z.string().optional().describe('Custom charset 4'),
    hash_list_id: z.number().int().describe('Hash list ID'),
    word_list: AttackResourceFileOut.optional().describe('Word list resource'),
    rule_list: AttackResourceFileOut.optional().describe('Rule list resource'),
    mask_list: AttackResourceFileOut.optional().describe('Mask list resource'),
    hash_list_url: z.string().describe('Hash list download URL'),
    hash_list_checksum: z.string().describe('Hash list checksum'),
    priority: z.number().int().describe('Attack priority'),
    position: z.number().int().describe('Attack position in campaign'),
    start_time: z.union([z.string().datetime(), z.null()]).describe('Attack start time'),
    end_time: z.union([z.string().datetime(), z.null()]).describe('Attack end time'),
    campaign_id: z.union([z.number().int(), z.null()]).describe('Campaign ID'),
    template_id: z.union([z.number().int(), z.null()]).describe('Template ID'),
    modifiers: z
        .union([z.array(z.string()), z.null()])
        .optional()
        .describe('Attack modifiers'),
});
export type AttackOut = z.infer<typeof AttackOut>;

/**
 * Attack template schema
 * Template for creating standardized attacks
 */
export const AttackTemplate = z.object({
    mode: AttackMode.describe('Attack mode (e.g., dictionary, mask, etc.)'),
    wordlist_guid: z
        .string()
        .uuid()
        .optional()
        .describe('GUID of the wordlist resource, if applicable'),
    rulelist_guid: z
        .string()
        .uuid()
        .optional()
        .describe('GUID of the rule list resource, if applicable'),
    masklist_guid: z
        .string()
        .uuid()
        .optional()
        .describe('GUID of the mask list resource, if applicable'),
    min_length: z.number().int().optional().describe('Minimum password length'),
    max_length: z.number().int().optional().describe('Maximum password length'),
    masks: z.array(z.string()).optional().describe('List of mask patterns, if applicable'),
    masks_inline: z.array(z.string()).optional().describe('Ephemeral mask list lines, if inlined'),
    wordlist_inline: z
        .array(z.string())
        .optional()
        .describe('Ephemeral wordlist lines, if inlined'),
    rules_inline: z.array(z.string()).optional().describe('Ephemeral rule list lines, if inlined'),
    charset_1: z.string().optional().describe('Custom charset 1'),
    charset_2: z.string().optional().describe('Custom charset 2'),
    charset_3: z.string().optional().describe('Custom charset 3'),
    charset_4: z.string().optional().describe('Custom charset 4'),
    increment: z.boolean().optional().describe('Enable increment mode'),
    increment_min: z.number().int().optional().describe('Minimum increment length'),
    increment_max: z.number().int().optional().describe('Maximum increment length'),
    optimized: z.boolean().optional().describe('Use optimized kernel'),
    slow_candidates: z.boolean().optional().describe('Enable slow candidates'),
    workload_profile: z.number().int().optional().describe('Workload profile'),
    disable_markov: z.boolean().optional().describe('Disable Markov mode'),
    classic_markov: z.boolean().optional().describe('Enable classic Markov mode'),
    markov_threshold: z.number().int().optional().describe('Markov threshold'),
    left_rule: z.string().optional().describe('Left-hand rule for combinator attacks'),
    right_rule: z.string().optional().describe('Right-hand rule for combinator attacks'),
});
export type AttackTemplate = z.infer<typeof AttackTemplate>;

// Attack management operations
/**
 * Attack move request schema
 * Request to move attack position within campaign
 */
export const AttackMoveRequest = z.object({
    direction: AttackMoveDirection.describe('Direction to move attack'),
});
export type AttackMoveRequest = z.infer<typeof AttackMoveRequest>;

// Re-export AttackResourceFileOut from resources for convenience
export { AttackResourceFileOut } from './resources';
