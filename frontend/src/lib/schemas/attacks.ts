/**
 * Attack schemas for CipherSwarm
 * Used by /api/v1/web/attacks/* endpoints
 */

import { z } from 'zod';
import {
    AttackMode,
    AttackState,
    AttackResourceType,
    AttackMoveDirection,
    WordlistSource,
} from './base';

// Core attack schemas
/**
 * Attack basic schema
 * Essential attack information for list views
 */
export const AttackBasic = z.object({
    id: z.number().describe('Attack ID'),
    name: z.string().describe('Attack name'),
    attack_mode: AttackMode.describe('Type of attack (dictionary, mask, hybrid)'),
    state: AttackState.describe('Current attack state'),
    priority: z.number().describe('Attack priority within campaign'),
    created_at: z.string().describe('Creation timestamp'),
    updated_at: z.string().describe('Last update timestamp'),
});
export type AttackBasic = z.infer<typeof AttackBasic>;

/**
 * Attack summary schema
 * Attack information with progress and performance metrics
 */
export const AttackSummary = z.object({
    id: z.number().describe('Attack ID'),
    name: z.string().describe('Attack name'),
    attack_mode: AttackMode.describe('Type of attack'),
    state: AttackState.describe('Current attack state'),
    priority: z.number().describe('Attack priority'),
    progress_percentage: z.number().describe('Attack completion percentage'),
    keyspace_total: z.number().optional().describe('Total keyspace size'),
    keyspace_searched: z.number().optional().describe('Searched keyspace'),
    hash_speed: z.number().optional().describe('Current hash rate'),
    estimated_time_remaining: z.string().optional().describe('Estimated completion time'),
    created_at: z.string().describe('Creation timestamp'),
    updated_at: z.string().describe('Last update timestamp'),
});
export type AttackSummary = z.infer<typeof AttackSummary>;

/**
 * Attack creation schema
 * Required fields for creating a new attack
 */
export const AttackCreate = z.object({
    name: z.string().describe('Attack name'),
    attack_mode: AttackMode.describe('Type of attack'),
    priority: z.number().describe('Attack priority'),
    campaign_id: z.number().describe('Campaign ID this attack belongs to'),
    hash_list_id: z.number().describe('Hash list ID to attack'),
    wordlist_id: z.number().optional().describe('Wordlist resource ID'),
    rule_list_id: z.number().optional().describe('Rule list resource ID'),
    mask: z.string().optional().describe('Mask pattern for mask attacks'),
    increment_mode: z.boolean().optional().describe('Enable increment mode'),
    increment_min: z.number().optional().describe('Minimum increment length'),
    increment_max: z.number().optional().describe('Maximum increment length'),
    optimized_kernel: z.boolean().optional().describe('Use optimized kernel'),
    slow_candidates: z.boolean().optional().describe('Enable slow candidates'),
});
export type AttackCreate = z.infer<typeof AttackCreate>;

/**
 * Attack update schema
 * Optional fields for updating an existing attack
 */
export const AttackUpdate = z.object({
    name: z.string().optional().describe('Attack name'),
    priority: z.number().optional().describe('Attack priority'),
    state: AttackState.optional().describe('Attack state'),
});
export type AttackUpdate = z.infer<typeof AttackUpdate>;

/**
 * Attack output schema
 * Complete attack information including all configuration details
 */
export const AttackOut = z.object({
    id: z.number().describe('Attack ID'),
    name: z.string().describe('Attack name'),
    attack_mode: AttackMode.describe('Type of attack'),
    state: AttackState.describe('Current attack state'),
    priority: z.number().describe('Attack priority'),
    campaign_id: z.number().describe('Campaign ID'),
    hash_list_id: z.number().describe('Hash list ID'),
    wordlist_id: z.number().optional().describe('Wordlist resource ID'),
    rule_list_id: z.number().optional().describe('Rule list resource ID'),
    mask: z.string().optional().describe('Mask pattern'),
    charset_1: z.string().optional().describe('Custom charset 1'),
    charset_2: z.string().optional().describe('Custom charset 2'),
    charset_3: z.string().optional().describe('Custom charset 3'),
    charset_4: z.string().optional().describe('Custom charset 4'),
    increment_mode: z.boolean().describe('Increment mode enabled'),
    increment_min: z.number().optional().describe('Minimum increment length'),
    increment_max: z.number().optional().describe('Maximum increment length'),
    optimized_kernel: z.boolean().describe('Optimized kernel enabled'),
    slow_candidates: z.boolean().describe('Slow candidates enabled'),
    created_at: z.string().describe('Creation timestamp'),
    updated_at: z.string().describe('Last update timestamp'),
});
export type AttackOut = z.infer<typeof AttackOut>;

// Attack resources
/**
 * Attack resource file output schema
 * Information about resource files associated with attacks
 */
export const AttackResourceFileOut = z.object({
    id: z.number().describe('Resource file ID'),
    name: z.string().describe('Resource file name'),
    type: AttackResourceType.describe('Type of resource'),
    size: z.number().describe('File size in bytes'),
    checksum: z.string().describe('File checksum'),
    upload_date: z.string().describe('Upload timestamp'),
    line_count: z.number().optional().describe('Number of lines in file'),
});
export type AttackResourceFileOut = z.infer<typeof AttackResourceFileOut>;

// Attack templates
/**
 * Attack template schema
 * Template for creating standardized attacks
 */
export const AttackTemplate = z.object({
    name: z.string().describe('Template name'),
    attack_mode: AttackMode.describe('Attack mode'),
    description: z.string().optional().describe('Template description'),
    default_priority: z.number().describe('Default priority'),
    configuration: z.record(z.unknown()).describe('Template configuration'),
});
export type AttackTemplate = z.infer<typeof AttackTemplate>;

/**
 * Attack template record creation schema
 * Required fields for creating attack template records
 */
export const AttackTemplateRecordCreate = z.object({
    name: z.string().describe('Template name'),
    attack_mode: AttackMode.describe('Attack mode'),
    description: z.string().optional().describe('Template description'),
    configuration: z.record(z.unknown()).describe('Template configuration'),
    is_public: z.boolean().describe('Whether template is publicly available'),
});
export type AttackTemplateRecordCreate = z.infer<typeof AttackTemplateRecordCreate>;

/**
 * Attack template record output schema
 * Complete attack template record information
 */
export const AttackTemplateRecordOut = z.object({
    id: z.number().describe('Template ID'),
    name: z.string().describe('Template name'),
    attack_mode: AttackMode.describe('Attack mode'),
    description: z.string().optional().describe('Template description'),
    configuration: z.record(z.unknown()).describe('Template configuration'),
    is_public: z.boolean().describe('Whether template is publicly available'),
    created_by: z.string().describe('Template creator'),
    created_at: z.string().describe('Creation timestamp'),
});
export type AttackTemplateRecordOut = z.infer<typeof AttackTemplateRecordOut>;

/**
 * Attack template record update schema
 * Optional fields for updating attack templates
 */
export const AttackTemplateRecordUpdate = z.object({
    name: z.string().optional().describe('Template name'),
    description: z.string().optional().describe('Template description'),
    configuration: z.record(z.unknown()).optional().describe('Template configuration'),
    is_public: z.boolean().optional().describe('Whether template is publicly available'),
});
export type AttackTemplateRecordUpdate = z.infer<typeof AttackTemplateRecordUpdate>;

// Attack management operations
/**
 * Attack bulk delete request schema
 * Request to delete multiple attacks
 */
export const AttackBulkDeleteRequest = z.object({
    attack_ids: z.array(z.number()).describe('List of attack IDs to delete'),
});
export type AttackBulkDeleteRequest = z.infer<typeof AttackBulkDeleteRequest>;

/**
 * Attack move request schema
 * Request to move attack position within campaign
 */
export const AttackMoveRequest = z.object({
    direction: AttackMoveDirection.describe('Direction to move attack'),
});
export type AttackMoveRequest = z.infer<typeof AttackMoveRequest>;

/**
 * Reorder attacks request schema
 * Request to reorder attacks in a campaign
 */
export const ReorderAttacksRequest = z.object({
    attack_ids: z.array(z.number()).describe('Attack IDs in desired order'),
});
export type ReorderAttacksRequest = z.infer<typeof ReorderAttacksRequest>;

/**
 * Reorder attacks response schema
 * Response confirming attack reordering
 */
export const ReorderAttacksResponse = z.object({
    success: z.boolean().describe('Whether reordering was successful'),
    new_order: z.array(z.number()).describe('New attack order'),
});
export type ReorderAttacksResponse = z.infer<typeof ReorderAttacksResponse>;

// Attack estimation and validation
/**
 * Estimate attack request schema
 * Request to estimate attack completion time and resource requirements
 */
export const EstimateAttackRequest = z.object({
    attack_mode: AttackMode.describe('Attack mode'),
    wordlist_id: z.number().optional().describe('Wordlist resource ID'),
    rule_list_id: z.number().optional().describe('Rule list resource ID'),
    mask: z.string().optional().describe('Mask pattern'),
    hash_type: z.number().describe('Hash type to estimate for'),
});
export type EstimateAttackRequest = z.infer<typeof EstimateAttackRequest>;

/**
 * Mask validation request schema
 * Request to validate mask pattern syntax
 */
export const MaskValidationRequest = z.object({
    mask: z.string().describe('Mask pattern to validate'),
    charset_1: z.string().optional().describe('Custom charset 1'),
    charset_2: z.string().optional().describe('Custom charset 2'),
    charset_3: z.string().optional().describe('Custom charset 3'),
    charset_4: z.string().optional().describe('Custom charset 4'),
});
export type MaskValidationRequest = z.infer<typeof MaskValidationRequest>;

/**
 * Mask validation response schema
 * Result of mask pattern validation
 */
export const MaskValidationResponse = z.object({
    valid: z.boolean().describe('Whether mask is valid'),
    keyspace_size: z.number().optional().describe('Estimated keyspace size'),
    error_message: z.string().optional().describe('Validation error message'),
});
export type MaskValidationResponse = z.infer<typeof MaskValidationResponse>;

/**
 * Brute force mask request schema
 * Request to generate brute force mask patterns
 */
export const BruteForceMaskRequest = z.object({
    min_length: z.number().describe('Minimum password length'),
    max_length: z.number().describe('Maximum password length'),
    charset: z.string().describe('Character set to use'),
});
export type BruteForceMaskRequest = z.infer<typeof BruteForceMaskRequest>;

/**
 * Brute force mask response schema
 * Generated brute force mask patterns
 */
export const BruteForceMaskResponse = z.object({
    masks: z.array(z.string()).describe('Generated mask patterns'),
    total_keyspace: z.number().describe('Total keyspace size'),
});
export type BruteForceMaskResponse = z.infer<typeof BruteForceMaskResponse>;

// Attack performance and monitoring
/**
 * Attack performance summary schema
 * Performance metrics for an attack
 */
export const AttackPerformanceSummary = z.object({
    attack_id: z.number().describe('Attack ID'),
    average_hash_rate: z.number().describe('Average hash rate'),
    peak_hash_rate: z.number().describe('Peak hash rate'),
    total_runtime: z.number().describe('Total runtime in seconds'),
    efficiency_percentage: z.number().describe('Efficiency percentage'),
});
export type AttackPerformanceSummary = z.infer<typeof AttackPerformanceSummary>;

/**
 * Attack campaign response schema
 * Attack information with associated campaign details
 */
export const AttackCampaignResponse = z.object({
    attack: AttackOut.describe('Attack information'),
    campaign_name: z.string().describe('Campaign name'),
    campaign_state: z.string().describe('Campaign state'),
});
export type AttackCampaignResponse = z.infer<typeof AttackCampaignResponse>;

// Attack editor context
/**
 * Attack editor context schema
 * Context information for attack editing interface
 */
export const AttackEditorContext = z.object({
    attack: AttackOut.optional().describe('Existing attack (for editing)'),
    available_wordlists: z.array(z.unknown()).describe('Available wordlist resources'),
    available_rule_lists: z.array(z.unknown()).describe('Available rule list resources'),
    supported_hash_types: z.array(z.number()).describe('Supported hash types'),
    default_configuration: z.record(z.unknown()).describe('Default configuration values'),
});
export type AttackEditorContext = z.infer<typeof AttackEditorContext>;
