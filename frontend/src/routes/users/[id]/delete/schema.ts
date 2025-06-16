import { z } from 'zod';

export const deleteUserSchema = z.object({
	message: z.string().optional()
});

export type DeleteUserSchema = typeof deleteUserSchema;
