import { z } from 'zod';
import {
    DateTimeSchema,
    IdSchema,
    OptionalNullableStringSchema,
    createListResponseSchema,
} from './common';

// Project schemas
export const ProjectSchema = z
    .object({
        id: IdSchema,
        name: z.string(),
        description: OptionalNullableStringSchema,
        created_at: DateTimeSchema,
        updated_at: DateTimeSchema,
    })
    .strict();

export const ProjectListResponseSchema = createListResponseSchema(ProjectSchema);

// Project context for authentication
export const ProjectContextDetailSchema = z
    .object({
        id: IdSchema,
        name: z.string(),
        role: z.string(),
    })
    .strict();

// Form validation schemas
export const projectFormSchema = z.object({
    name: z.string().min(1, 'Project name is required').max(255, 'Project name too long'),
    description: z.string().max(1024, 'Description too long').optional(),
});

export const projectSelectionSchema = z.object({
    project_id: IdSchema,
});

// Types
export type Project = z.infer<typeof ProjectSchema>;
export type ProjectListResponse = z.infer<typeof ProjectListResponseSchema>;
export type ProjectContextDetail = z.infer<typeof ProjectContextDetailSchema>;
export type ProjectFormData = z.infer<typeof projectFormSchema>;
export type ProjectSelection = z.infer<typeof projectSelectionSchema>;

// Legacy aliases for backward compatibility
export const ProjectRead = ProjectSchema;
export const ListProjectsResponse = ProjectListResponseSchema;
export type ProjectReadType = Project;
export type ListProjectsResponseType = ProjectListResponse;
