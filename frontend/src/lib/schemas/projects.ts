/**
 * Project schemas for CipherSwarm
 * Used by /api/v1/web/projects/* endpoints
 */

import { z } from 'zod';
import {
    DateTimeSchema,
    IdSchema,
    OptionalNullableStringSchema,
    createListResponseSchema,
} from './common';

// Core project schemas
export const ProjectRead = z.object({
    id: z.number(),
    name: z.string(),
    description: z.string().optional(),
    created_at: z.string(),
    updated_at: z.string(),
    owner_id: z.string(),
    is_archived: z.boolean(),
    member_count: z.number().optional(),
    campaign_count: z.number().optional(),
});
export type ProjectRead = z.infer<typeof ProjectRead>;

export const ProjectCreate = z.object({
    name: z.string(),
    description: z.string().optional(),
});
export type ProjectCreate = z.infer<typeof ProjectCreate>;

export const ProjectUpdate = z.object({
    name: z.string().optional(),
    description: z.string().optional(),
    is_archived: z.boolean().optional(),
});
export type ProjectUpdate = z.infer<typeof ProjectUpdate>;

// Project listings and responses
export const ListProjectsResponse = z.object({
    projects: z.array(ProjectRead),
    total_count: z.number(),
    page: z.number(),
    page_size: z.number(),
});
export type ListProjectsResponse = z.infer<typeof ListProjectsResponse>;

export const ProjectListResponse = z.object({
    items: z.array(ProjectRead),
    total_count: z.number(),
    page: z.number(),
    page_size: z.number(),
    total_pages: z.number(),
});
export type ProjectListResponse = z.infer<typeof ProjectListResponse>;

// Project users
export const ProjectUsersResponse = z.object({
    users: z.array(z.unknown()),
    total_count: z.number(),
    page: z.number(),
    page_size: z.number(),
});
export type ProjectUsersResponse = z.infer<typeof ProjectUsersResponse>;

// Form validation schemas
export const projectFormSchema = z.object({
    name: z.string().min(1, 'Project name is required').max(255, 'Project name too long'),
    description: z.string().max(1024, 'Description too long').optional(),
});
export type ProjectFormData = z.infer<typeof projectFormSchema>;

export const projectSelectionSchema = z.object({
    project_id: z.number(),
});
export type ProjectSelection = z.infer<typeof projectSelectionSchema>;

// Legacy aliases for backward compatibility
export const ProjectReadType = ProjectRead;
export type ListProjectsResponseType = ListProjectsResponse;
export type Project = ProjectRead;
