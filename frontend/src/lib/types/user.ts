import type { UserRead, UserCreate, UserUpdate, UserCreateControl } from '$lib/schemas/users';

// Re-export schema types directly
export type { UserRead, UserCreate, UserUpdate, UserCreateControl };

// User type alias for components that expect it
export type User = UserRead;

// For components that need additional properties, create specific interfaces
export interface UserProfile extends UserRead {
    // Additional display properties if needed by specific components
    displayName?: string;
}
