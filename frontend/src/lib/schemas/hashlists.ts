/**
 * Hash list schemas for CipherSwarm
 * Used by /api/v1/web/hash_lists/* endpoints
 */

import { z } from 'zod';

// Core hash list schemas
export const HashListOut = z.object({
    id: z.number(),
    name: z.string(),
    description: z.string().optional(),
    hash_count: z.number(),
    cracked_count: z.number(),
    hash_type_id: z.number(),
    hash_type_name: z.string(),
    salt_format: z.string().optional(),
    created_at: z.string(),
    updated_at: z.string(),
    created_by: z.string(),
});
export type HashListOut = z.infer<typeof HashListOut>;

export const HashListCreate = z.object({
    name: z.string(),
    description: z.string().optional(),
    hash_type_id: z.number(),
    salt_format: z.string().optional(),
});
export type HashListCreate = z.infer<typeof HashListCreate>;

export const HashListUpdateData = z.object({
    name: z.string().optional(),
    description: z.string().optional(),
});
export type HashListUpdateData = z.infer<typeof HashListUpdateData>;

// Hash list pagination
export const PaginatedResponse_HashListOut_ = z.object({
    items: z.array(HashListOut),
    total: z.number(),
    page: z.number(),
    page_size: z.number(),
    total_pages: z.number(),
});
export type PaginatedResponse_HashListOut_ = z.infer<typeof PaginatedResponse_HashListOut_>;

// Hash items
export const HashItemOut = z.object({
    id: z.number(),
    hash: z.string(),
    salt: z.string().optional(),
    plaintext: z.string().optional(),
    is_cracked: z.boolean(),
    cracked_at: z.string().optional(),
    metadata: z.record(z.unknown()).optional(),
});
export type HashItemOut = z.infer<typeof HashItemOut>;

// Hash types
export const HashTypeDropdownItem = z.object({
    id: z.number(),
    name: z.string(),
    description: z.string().optional(),
    hashcat_mode: z.number(),
    category: z.string(),
});
export type HashTypeDropdownItem = z.infer<typeof HashTypeDropdownItem>;

// Hash guessing
export const HashGuessCandidate = z.object({
    hash: z.string(),
    plaintext: z.string(),
    confidence: z.number(),
});
export type HashGuessCandidate = z.infer<typeof HashGuessCandidate>;

export const HashGuessResponse = z.object({
    success: z.boolean(),
    candidates: z.array(HashGuessCandidate),
});
export type HashGuessResponse = z.infer<typeof HashGuessResponse>;

export const HashGuessResults = z.object({
    results: z.array(HashGuessResponse),
});
export type HashGuessResults = z.infer<typeof HashGuessResults>;

// Hashcat specific
export const HashcatGuess = z.object({
    hash: z.string(),
    salt: z.string().optional(),
    plaintext: z.string(),
    hex_salt: z.string().optional(),
    hex_plain: z.string().optional(),
});
export type HashcatGuess = z.infer<typeof HashcatGuess>;

export const HashcatResult = z.object({
    timestamp: z.string(),
    results: z.array(HashcatGuess),
});
export type HashcatResult = z.infer<typeof HashcatResult>;
