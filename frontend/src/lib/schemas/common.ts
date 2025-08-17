import { z } from 'zod';

// Common validation patterns used across the application

// Pagination schemas
export const PaginationRequestSchema = z.object({
    page: z.number().int().min(1).default(1),
    page_size: z.number().int().min(1).max(100).default(20),
    search: z.string().nullish(),
});

export const PaginationResponseSchema = z.object({
    total: z.number().int(),
    page: z.number().int(),
    page_size: z.number().int(),
    total_pages: z.number().int(),
});

// Generic list response schema
export function createListResponseSchema<T extends z.ZodTypeAny>(itemSchema: T) {
    return z.object({
        items: z.array(itemSchema),
        total: z.number().int(),
        page: z.number().int(),
        page_size: z.number().int(),
        total_pages: z.number().int(),
    });
}

// Common field validation patterns
export const IdSchema = z.number().int().positive();
export const UuidSchema = z.string().uuid();
export const EmailSchema = z.string().email();
export const UrlSchema = z.string().url();
export const DateTimeSchema = z.string().datetime({ offset: true });
export const nullishDateTimeSchema = z.string().datetime({ offset: true }).nullish();

// Common enums
export const SortDirectionSchema = z.enum(['asc', 'desc']);

// Validation helpers
export const NonEmptyStringSchema = z.string().min(1, 'This field is required');
export const nullishStringSchema = z.string().nullish();
export const NullableStringSchema = z.string().nullable();
export const nullishNullableStringSchema = z.string().nullish();

// File validation
export const FileChecksumSchema = z.string().regex(/^[a-f0-9]{32}$/i, 'Invalid MD5 checksum');
export const FileSizeSchema = z.number().int().min(0);
export const LineCountSchema = z.number().int().min(0);

// Common response patterns
export const SuccessResponseSchema = z.object({
    success: z.boolean().default(true),
    message: z.string().nullish(),
});

export const ErrorResponseSchema = z.object({
    detail: z.string(),
    type: z.string().nullish(),
});

// Types
export type PaginationRequest = z.infer<typeof PaginationRequestSchema>;
export type PaginationResponse = z.infer<typeof PaginationResponseSchema>;
export type SuccessResponse = z.infer<typeof SuccessResponseSchema>;
export type ErrorResponse = z.infer<typeof ErrorResponseSchema>;
