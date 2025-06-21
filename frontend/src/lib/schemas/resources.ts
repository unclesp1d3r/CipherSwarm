/**
 * Resource schemas for CipherSwarm
 * Used by /api/v1/web/resources/* endpoints
 */

import { z } from 'zod';
import { AttackResourceType } from './base';

// Core resource schemas
/**
 * Resource list item schema
 * Basic resource information for list views
 */
export const ResourceListItem = z.object({
    id: z.number().describe('Resource ID'),
    filename: z.string().describe('Resource name'),
    file_size: z.number().describe('File size in bytes'),
    line_count: z.number().optional().describe('Number of lines in file'),
    checksum_md5: z.string().describe('File checksum (MD5)'),
    resource_type: AttackResourceType.describe('Type of resource'),
    sensitive: z.boolean().describe('Whether resource contains sensitive data'),
    description: z.string().optional().describe('Resource description'),
    created_at: z.string().describe('Creation timestamp'),
    updated_at: z.string().describe('Last update timestamp'),
    uploaded_by: z.string().optional().describe('User who uploaded the resource'),
});
export type ResourceListItem = z.infer<typeof ResourceListItem>;

/**
 * Resource list response schema
 * Paginated list of resources with filtering options
 */
export const ResourceListResponse = z.object({
    items: z.array(ResourceListItem).describe('List of resources'),
    total_count: z.number().describe('Total number of resources'),
    page: z.number().describe('Current page number'),
    page_size: z.number().describe('Number of resources per page'),
    total_pages: z.number().describe('Total number of pages'),
    resource_type: AttackResourceType.optional().describe('Filtered resource type'),
    search: z.string().optional().describe('Search query'),
});
export type ResourceListResponse = z.infer<typeof ResourceListResponse>;

/**
 * Resource detail response schema
 * Complete resource information including metadata and usage statistics
 */
export const ResourceDetailResponse = z.object({
    id: z.number().describe('Resource ID'),
    filename: z.string().describe('Resource name'),
    file_size: z.number().describe('File size in bytes'),
    line_count: z.number().optional().describe('Number of lines in file'),
    checksum_md5: z.string().describe('File checksum'),
    resource_type: AttackResourceType.describe('Type of resource'),
    sensitive: z.boolean().describe('Whether resource contains sensitive data'),
    description: z.string().optional().describe('Resource description'),
    created_at: z.string().describe('Creation timestamp'),
    updated_at: z.string().describe('Last update timestamp'),
    uploaded_by: z.string().optional().describe('User who uploaded the resource'),
    project_id: z.number().describe('Project ID'),
    usage_count: z.number().describe('Number of times resource has been used'),
    last_used: z.string().optional().describe('Last usage timestamp'),
});
export type ResourceDetailResponse = z.infer<typeof ResourceDetailResponse>;

// Resource dropdown items
/**
 * Resource dropdown item schema
 * Minimal resource information for dropdown selections
 */
export const ResourceDropdownItem = z.object({
    id: z.number().describe('Resource ID'),
    filename: z.string().describe('Resource name'),
    description: z.string().optional().describe('Resource description'),
    resource_type: AttackResourceType.describe('Type of resource'),
    line_count: z.number().optional().describe('Number of lines in file'),
    file_size: z.number().describe('File size in bytes'),
});
export type ResourceDropdownItem = z.infer<typeof ResourceDropdownItem>;

/**
 * Wordlist item schema
 * Wordlist-specific information for dropdown selections
 */
export const WordlistItem = z.object({
    id: z.number().describe('Wordlist ID'),
    name: z.string().describe('Wordlist name'),
    description: z.string().optional().describe('Wordlist description'),
    line_count: z.number().describe('Number of words in wordlist'),
});
export type WordlistItem = z.infer<typeof WordlistItem>;

/**
 * Wordlist dropdown response schema
 * List of available wordlists for selection
 */
export const WordlistDropdownResponse = z.object({
    wordlists: z.array(WordlistItem).describe('Available wordlists'),
});
export type WordlistDropdownResponse = z.infer<typeof WordlistDropdownResponse>;

/**
 * Rulelist item schema
 * Rulelist-specific information for dropdown selections
 */
export const RulelistItem = z.object({
    id: z.number().describe('Rulelist ID'),
    name: z.string().describe('Rulelist name'),
    description: z.string().optional().describe('Rulelist description'),
    line_count: z.number().describe('Number of rules in rulelist'),
});
export type RulelistItem = z.infer<typeof RulelistItem>;

/**
 * Rulelist dropdown response schema
 * List of available rulelists for selection
 */
export const RulelistDropdownResponse = z.object({
    rulelists: z.array(RulelistItem).describe('Available rulelists'),
});
export type RulelistDropdownResponse = z.infer<typeof RulelistDropdownResponse>;

// Resource content and lines
/**
 * Resource line schema
 * Individual line within a resource file
 */
export const ResourceLine = z.object({
    id: z.number().describe('Line ID'),
    line_number: z.number().describe('Line number within file'),
    content: z.string().describe('Line content'),
    resource_id: z.number().describe('Resource ID'),
    is_comment: z.boolean().optional().describe('Whether line is a comment'),
});
export type ResourceLine = z.infer<typeof ResourceLine>;

/**
 * Resource lines response schema
 * Paginated view of resource file contents
 */
export const ResourceLinesResponse = z.object({
    lines: z.array(ResourceLine).describe('Resource file lines'),
    total_count: z.number().describe('Total number of lines in file'),
    page: z.number().describe('Current page number'),
    page_size: z.number().describe('Number of lines per page'),
    total_pages: z.number().describe('Total number of pages'),
});
export type ResourceLinesResponse = z.infer<typeof ResourceLinesResponse>;

/**
 * Resource content response schema
 * Full or partial content of a resource file
 */
export const ResourceContentResponse = z.object({
    content: z.string().describe('Resource file content'),
    filename: z.string().describe('Original filename'),
    resource_type: AttackResourceType.describe('Type of resource'),
    line_count: z.number().describe('Number of lines in file'),
    file_size: z.number().describe('File size in bytes'),
    encoding: z.string().describe('Content encoding (e.g., utf-8)'),
    is_truncated: z.boolean().describe('Whether content is truncated'),
    total_size: z.number().describe('Total file size in bytes'),
});
export type ResourceContentResponse = z.infer<typeof ResourceContentResponse>;

/**
 * Resource preview response schema
 * Preview of resource file content with sample lines
 */
export const ResourcePreviewResponse = z.object({
    lines: z.array(z.string()).describe('Sample lines from the resource'),
    total_lines: z.number().describe('Total number of lines'),
    truncated: z.boolean().describe('Whether content is truncated'),
    file_size: z.number().describe('File size in bytes'),
    encoding: z.string().describe('File encoding'),
});
export type ResourcePreviewResponse = z.infer<typeof ResourcePreviewResponse>;

// Resource updates
/**
 * Resource update request schema
 * Fields that can be updated for an existing resource
 */
export const ResourceUpdateRequest = z.object({
    filename: z.string().optional().describe('New resource name'),
    description: z.string().optional().describe('New resource description'),
    sensitive: z.boolean().optional().describe('Whether resource contains sensitive data'),
});
export type ResourceUpdateRequest = z.infer<typeof ResourceUpdateRequest>;

// Resource uploads
/**
 * Resource upload form schema
 * Form validation schema for resource uploads
 */
export const ResourceUploadFormSchema = z.object({
    name: z.string().min(1).describe('Resource name'),
    description: z.string().optional().describe('Resource description'),
    resource_type: AttackResourceType.describe('Type of resource'),
    sensitive: z.boolean().describe('Whether resource contains sensitive data'),
});
export type ResourceUploadFormSchema = z.infer<typeof ResourceUploadFormSchema>;

/**
 * Resource upload metadata schema
 * Metadata provided during resource upload
 */
export const ResourceUploadMeta = z.object({
    filename: z.string().describe('Original filename'),
    content_type: z.string().describe('MIME content type'),
    size: z.number().describe('File size in bytes'),
});
export type ResourceUploadMeta = z.infer<typeof ResourceUploadMeta>;

/**
 * Resource upload response schema
 * Response after initiating a resource upload
 */
export const ResourceUploadResponse = z.object({
    upload_id: z.string().describe('Unique upload identifier'),
    upload_url: z.string().describe('Presigned URL for file upload'),
    max_file_size: z.number().describe('Maximum allowed file size'),
    allowed_content_types: z.array(z.string()).describe('Allowed MIME types'),
    expires_at: z.string().describe('Upload URL expiration timestamp'),
});
export type ResourceUploadResponse = z.infer<typeof ResourceUploadResponse>;

/**
 * Resource uploaded response schema
 * Response after successful resource upload completion
 */
export const ResourceUploadedResponse = z.object({
    resource_id: z.number().describe('Created resource ID'),
    name: z.string().describe('Resource name'),
    file_size: z.number().describe('Uploaded file size'),
    checksum_md5: z.string().describe('File checksum'),
    line_count: z.number().optional().describe('Number of lines processed'),
    processing_status: z.string().describe('Processing status'),
});
export type ResourceUploadedResponse = z.infer<typeof ResourceUploadedResponse>;

// Resource usage
/**
 * Resource usage point schema
 * Single usage data point for analytics
 */
export const ResourceUsagePoint = z.object({
    date: z.string().describe('Usage date'),
    usage_count: z.number().describe('Number of times used'),
    unique_campaigns: z.number().describe('Number of unique campaigns'),
});
export type ResourceUsagePoint = z.infer<typeof ResourceUsagePoint>;

// Rule explanations
/**
 * Rule explanation schema
 * Explanation of a hashcat rule
 */
export const RuleExplanation = z.object({
    rule: z.string().describe('Original rule'),
    explanation: z.string().describe('Human-readable explanation'),
    examples: z.array(z.string()).describe('Example transformations'),
});
export type RuleExplanation = z.infer<typeof RuleExplanation>;

/**
 * Rule explanation list schema
 * List of rule explanations
 */
export const RuleExplanationList = z.object({
    explanations: z.array(RuleExplanation).describe('List of rule explanations'),
});
export type RuleExplanationList = z.infer<typeof RuleExplanationList>;

// Form body schemas
/**
 * Add resource line form body schema
 * Form data for adding a line to a resource
 */
export const Body_add_resource_line_api_v1_web_resources__resource_id__lines_post = z.object({
    content: z.string().describe('Line content to add'),
    line_number: z.number().optional().describe('Specific line number to insert at'),
});
export type Body_add_resource_line_api_v1_web_resources__resource_id__lines_post = z.infer<
    typeof Body_add_resource_line_api_v1_web_resources__resource_id__lines_post
>;

/**
 * Update resource content form body schema
 * Form data for updating resource file content
 */
export const Body_update_resource_content_api_v1_web_resources__resource_id__content_patch =
    z.object({
        content: z.string().describe('New resource content'),
        encoding: z.string().optional().describe('Content encoding'),
    });
export type Body_update_resource_content_api_v1_web_resources__resource_id__content_patch = z.infer<
    typeof Body_update_resource_content_api_v1_web_resources__resource_id__content_patch
>;

/**
 * Update resource line form body schema
 * Form data for updating a specific line in a resource
 */
export const Body_update_resource_line_api_v1_web_resources__resource_id__lines__line_id__patch =
    z.object({
        content: z.string().describe('New line content'),
        is_comment: z.boolean().optional().describe('Whether line is a comment'),
    });
export type Body_update_resource_line_api_v1_web_resources__resource_id__lines__line_id__patch =
    z.infer<
        typeof Body_update_resource_line_api_v1_web_resources__resource_id__lines__line_id__patch
    >;

/**
 * Upload resource metadata form body schema
 * Form data for resource upload metadata
 */
export const Body_upload_resource_metadata_api_v1_web_resources__post = z.object({
    name: z.string().describe('Resource name'),
    description: z.string().optional().describe('Resource description'),
    resource_type: AttackResourceType.describe('Type of resource'),
    sensitive: z.boolean().describe('Whether resource contains sensitive data'),
    filename: z.string().describe('Original filename'),
    content_type: z.string().describe('MIME content type'),
    file_size: z.number().describe('File size in bytes'),
});
export type Body_upload_resource_metadata_api_v1_web_resources__post = z.infer<
    typeof Body_upload_resource_metadata_api_v1_web_resources__post
>;
