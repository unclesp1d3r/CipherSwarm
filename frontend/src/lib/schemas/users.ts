/**
 * User schemas for CipherSwarm
 * Used by /api/v1/web/users/* endpoints
 */

import { z } from 'zod';

// Core user schemas
export const UserRead = z.object({
    id: z.string(),
    username: z.string(),
    email: z.string(),
    first_name: z.string().optional(),
    last_name: z.string().optional(),
    role: z.string(),
    is_active: z.boolean(),
    created_at: z.string(),
    updated_at: z.string(),
    last_login_at: z.string().optional(),
});
export type UserRead = z.infer<typeof UserRead>;

export const UserCreate = z.object({
    username: z.string(),
    email: z.string(),
    password: z.string(),
    first_name: z.string().optional(),
    last_name: z.string().optional(),
    role: z.string(),
    is_active: z.boolean().optional(),
});
export type UserCreate = z.infer<typeof UserCreate>;

export const UserUpdate = z.object({
    username: z.string().optional(),
    email: z.string().optional(),
    first_name: z.string().optional(),
    last_name: z.string().optional(),
    role: z.string().optional(),
    is_active: z.boolean().optional(),
});
export type UserUpdate = z.infer<typeof UserUpdate>;

// User listings
export const UserListResponse = z.object({
    items: z.array(UserRead),
    total_count: z.number(),
    page: z.number(),
    page_size: z.number(),
    total_pages: z.number(),
});
export type UserListResponse = z.infer<typeof UserListResponse>;

export const PaginatedUserList = z.object({
    users: z.array(UserRead),
    total_count: z.number(),
    page: z.number(),
    page_size: z.number(),
    total_pages: z.number(),
});
export type PaginatedUserList = z.infer<typeof PaginatedUserList>;

// Control API user schema (not used in web but included for completeness)
export const UserCreateControl = z.object({
    username: z.string(),
    email: z.string(),
    password: z.string(),
    first_name: z.string().optional(),
    last_name: z.string().optional(),
    role: z.string(),
    is_active: z.boolean().optional(),
});
export type UserCreateControl = z.infer<typeof UserCreateControl>;
