import { z } from 'zod';

// Login form schema
export const loginSchema = z.object({
	email: z.string().email('Please enter a valid email address'),
	password: z.string().min(1, 'Password is required'),
	remember: z.boolean().default(false)
});

// User session schema
export const userSessionSchema = z.object({
	id: z.number(),
	email: z.string().email(),
	name: z.string(),
	role: z.enum(['admin', 'project_admin', 'user']),
	projects: z.array(
		z.object({
			id: z.number(),
			name: z.string(),
			role: z.enum(['admin', 'project_admin', 'user'])
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
