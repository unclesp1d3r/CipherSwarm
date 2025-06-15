import { z } from 'zod';

// Upload form schema
export const uploadSchema = z.object({
    uploadMode: z.enum(['text', 'file']),
    projectId: z.number(),
    textContent: z.string().optional(),
    fileName: z.string().optional(),
    fileLabel: z.string().optional(),
    selectedHashTypeId: z.string().optional()
});

export type UploadSchema = typeof uploadSchema;

// Hash guess results from API
export interface HashGuessResults {
    candidates: Array<{
        hash_type: number;
        name: string;
        confidence: number;
    }>;
}

// Hash type dropdown item
export interface HashTypeDropdownItem {
    mode: number;
    name: string;
    category: string;
    confidence?: number;
}

// Upload response from API
export interface UploadResponse {
    resource_id: number;
    presigned_url?: string;
    resource: {
        file_name: string;
    };
}

// Upload status response
export interface UploadStatusResponse {
    status: 'pending' | 'processing' | 'completed' | 'failed';
    progress?: number;
    message?: string;
}
