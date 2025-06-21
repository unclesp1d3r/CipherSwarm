/**
 * Upload schemas for CipherSwarm
 * Used by /api/v1/web/uploads/* endpoints
 */

import { z } from 'zod';
import { UploadProcessingStep } from './base';

// Core upload schemas
export const UploadStatusOut = z.object({
    id: z.string(),
    filename: z.string(),
    file_size: z.number(),
    hash_count: z.number().optional(),
    processed_count: z.number().optional(),
    error_count: z.number().optional(),
    processing_step: UploadProcessingStep,
    progress_percentage: z.number(),
    estimated_time_remaining: z.string().optional(),
    created_at: z.string(),
    updated_at: z.string(),
    completed_at: z.string().optional(),
    error_message: z.string().optional(),
});
export type UploadStatusOut = z.infer<typeof UploadStatusOut>;

// Upload errors
export const UploadErrorEntryOut = z.object({
    line_number: z.number(),
    content: z.string(),
    error_message: z.string(),
    severity: z.string(),
});
export type UploadErrorEntryOut = z.infer<typeof UploadErrorEntryOut>;

export const UploadErrorEntryListResponse = z.object({
    items: z.array(UploadErrorEntryOut),
    total_count: z.number(),
    page: z.number(),
    page_size: z.number(),
    total_pages: z.number(),
});
export type UploadErrorEntryListResponse = z.infer<typeof UploadErrorEntryListResponse>;

// Form body schemas
export const Body_upload_resource_metadata_api_v1_web_uploads__post = z.object({
    filename: z.string(),
    hash_type_id: z.number(),
    description: z.string().optional(),
    salt_format: z.string().optional(),
});
export type Body_upload_resource_metadata_api_v1_web_uploads__post = z.infer<
    typeof Body_upload_resource_metadata_api_v1_web_uploads__post
>;
