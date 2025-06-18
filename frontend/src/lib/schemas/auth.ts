import { z } from 'zod';

// Login form schema
export const loginSchema = z.object({
	email: z.string().email('Please enter a valid email address'),
	password: z.string().min(1, 'Password is required'),
	remember: z.boolean().default(false)
});

// Project detail schema (matches ProjectContextDetail from backend)
export const projectDetailSchema = z.object({
	id: z.number(),
	name: z.string()
});

// User detail schema (matches UserContextDetail from backend)
export const userDetailSchema = z.object({
	id: z.string(), // UUID from backend
	email: z.string().email(),
	name: z.string(),
	role: z.string() // Role as string from backend
});

// Context response schema (matches ContextResponse from backend)
export const contextResponseSchema = z.object({
	user: userDetailSchema,
	active_project: projectDetailSchema.nullable(),
	available_projects: z.array(projectDetailSchema)
});

// Legacy user session schema for backwards compatibility
// Transform ContextResponse into this format for existing code
export const userSessionSchema = z.object({
	id: z.string(), // Changed from number to string (UUID)
	email: z.string().email(),
	name: z.string(),
	role: z.enum(['admin', 'project_admin', 'user']),
	projects: z.array(
		z.object({
			id: z.number(),
			name: z.string(),
			role: z.enum(['admin', 'project_admin', 'user']) // This will need to be derived
		})
	),
	current_project_id: z.number().optional(),
	is_authenticated: z.boolean().default(false)
});

// Project selection schema
export const projectSelectionSchema = z.object({
	project_id: z.number()
});

// Types
export type LoginForm = z.infer<typeof loginSchema>;
export type UserSession = z.infer<typeof userSessionSchema>;
export type ProjectSelection = z.infer<typeof projectSelectionSchema>;
export type ContextResponse = z.infer<typeof contextResponseSchema>;
export type UserDetail = z.infer<typeof userDetailSchema>;
export type ProjectDetail = z.infer<typeof projectDetailSchema>;
