/**
 * Authentication schemas for CipherSwarm
 * Used by /api/v1/auth/* and /api/v1/web/auth/* endpoints
 */

import { z } from 'zod';
import { LoginResultLevel } from './base';

// Login request/response schemas
/**
 * Login request schema
 * Standard username/password authentication request
 */
export const LoginRequest = z.object({
    username: z.string(),
    password: z.string(),
});
export type LoginRequest = z.infer<typeof LoginRequest>;

/**
 * JWT login request schema
 * Form-based JWT authentication request
 */
export const JwtLoginRequest = z.object({
    username: z.string(),
    password: z.string(),
});
export type JwtLoginRequest = z.infer<typeof JwtLoginRequest>;

/**
 * Login result schema
 * Response containing login status and optional message
 */
export const LoginResult = z.object({
    success: z.boolean(),
    message: z.string().optional(),
    level: LoginResultLevel.optional(),
});
export type LoginResult = z.infer<typeof LoginResult>;

/**
 * Change password request schema
 * Request to change user password with current password verification
 */
export const ChangePasswordRequest = z.object({
    current_password: z.string(),
    new_password: z.string(),
});
export type ChangePasswordRequest = z.infer<typeof ChangePasswordRequest>;

/**
 * Refresh token request schema
 * Request to refresh JWT token using refresh token
 */
export const RefreshTokenRequest = z.object({
    refresh_token: z.string(),
});
export type RefreshTokenRequest = z.infer<typeof RefreshTokenRequest>;

// Context schemas
/**
 * User context detail schema
 * Information about the currently authenticated user
 */
export const UserContextDetail = z.object({
    id: z.string(),
    username: z.string(),
    email: z.string(),
    is_admin: z.boolean(),
});
export type UserContextDetail = z.infer<typeof UserContextDetail>;

/**
 * Project context detail schema
 * Information about the user's current project context
 */
export const ProjectContextDetail = z.object({
    id: z.number(),
    name: z.string(),
    role: z.string(),
});
export type ProjectContextDetail = z.infer<typeof ProjectContextDetail>;

/**
 * Context response schema
 * Combined user and project context information
 */
export const ContextResponse = z.object({
    user: UserContextDetail,
    project: ProjectContextDetail.optional(),
});
export type ContextResponse = z.infer<typeof ContextResponse>;

/**
 * Set context request schema
 * Request to change the user's current project context
 */
export const SetContextRequest = z.object({
    project_id: z.number(),
});
export type SetContextRequest = z.infer<typeof SetContextRequest>;

// API Key schemas
/**
 * API key information response schema
 * Information about user's API keys and permissions
 */
export const ApiKeyInfoResponse = z.object({
    has_api_key: z.boolean(),
    key_prefix: z.string().optional(),
    created_at: z.string().optional(),
});
export type ApiKeyInfoResponse = z.infer<typeof ApiKeyInfoResponse>;

/**
 * API key rotation response schema
 * Response when generating or rotating API keys
 */
export const ApiKeyRotationResponse = z.object({
    api_key: z.string(),
    message: z.string(),
});
export type ApiKeyRotationResponse = z.infer<typeof ApiKeyRotationResponse>;

// Form body schemas for API endpoints
/**
 * Login form body schema
 * Form data for web-based login endpoint
 */
export const Body_login_api_v1_web_auth_login_post = z.object({
    username: z.string(),
    password: z.string(),
});
export type Body_login_api_v1_web_auth_login_post = z.infer<
    typeof Body_login_api_v1_web_auth_login_post
>;

/**
 * JWT login form body schema
 * Form data for JWT-based login endpoint
 */
export const Body_jwt_login_api_v1_auth_jwt_login_post = z.object({
    username: z.string(),
    password: z.string(),
});
export type Body_jwt_login_api_v1_auth_jwt_login_post = z.infer<
    typeof Body_jwt_login_api_v1_auth_jwt_login_post
>;

/**
 * Change password form body schema
 * Form data for password change endpoint
 */
export const Body_change_password_api_v1_web_auth_change_password_post = z.object({
    current_password: z.string(),
    new_password: z.string(),
});
export type Body_change_password_api_v1_web_auth_change_password_post = z.infer<
    typeof Body_change_password_api_v1_web_auth_change_password_post
>;

/**
 * Refresh token form body schema
 * Form data for token refresh endpoint
 */
export const Body_refresh_token_api_v1_web_auth_refresh_post = z.object({
    refresh_token: z.string(),
});
export type Body_refresh_token_api_v1_web_auth_refresh_post = z.infer<
    typeof Body_refresh_token_api_v1_web_auth_refresh_post
>;
