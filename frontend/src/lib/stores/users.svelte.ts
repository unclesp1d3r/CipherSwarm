import type { User } from '$lib/types/user';

// Store state interfaces
interface UserState {
    users: User[];
    loading: boolean;
    error: string | null;
    totalCount: number;
    page: number;
    pageSize: number;
    totalPages: number;
    searchQuery: string | null;
}

interface UserDetailState {
    details: Record<string, User>;
    loading: Record<string, boolean>;
    errors: Record<string, string | null>;
}

// Create reactive state using SvelteKit 5 runes
const userState = $state<UserState>({
    users: [],
    loading: false,
    error: null,
    totalCount: 0,
    page: 1,
    pageSize: 20,
    totalPages: 0,
    searchQuery: null,
});

const userDetailState = $state<UserDetailState>({
    details: {},
    loading: {},
    errors: {},
});

// Derived stores at module level
const users = $derived(userState.users);
const usersLoading = $derived(userState.loading);
const usersError = $derived(userState.error);
const usersPagination = $derived({
    totalCount: userState.totalCount,
    page: userState.page,
    pageSize: userState.pageSize,
    totalPages: userState.totalPages,
    searchQuery: userState.searchQuery,
});

// Export functions that return the derived values
export function getUsers() {
    return users;
}

export function getUsersLoading() {
    return usersLoading;
}

export function getUsersError() {
    return usersError;
}

export function getUsersPagination() {
    return usersPagination;
}

// User store actions
export const usersStore = {
    // Getters for reactive state
    get users() {
        return userState.users;
    },
    get loading() {
        return userState.loading;
    },
    get error() {
        return userState.error;
    },
    get pagination() {
        return {
            totalCount: userState.totalCount,
            page: userState.page,
            pageSize: userState.pageSize,
            totalPages: userState.totalPages,
            searchQuery: userState.searchQuery,
        };
    },

    // Basic user operations
    setUsers: (
        users: User[],
        totalCount: number,
        page: number,
        pageSize: number,
        totalPages: number,
        searchQuery: string | null = null
    ) => {
        userState.users = users;
        userState.totalCount = totalCount;
        userState.page = page;
        userState.pageSize = pageSize;
        userState.totalPages = totalPages;
        userState.searchQuery = searchQuery;
        userState.loading = false;
        userState.error = null;
    },

    addUser: (user: User) => {
        userState.users = [...userState.users, user];
        userState.totalCount = userState.totalCount + 1;
    },

    updateUser: (userId: string, updatedUser: Partial<User>) => {
        userState.users = userState.users.map((user) =>
            user.id === userId ? { ...user, ...updatedUser } : user
        );

        // Update detail cache if exists
        if (userDetailState.details[userId]) {
            userDetailState.details[userId] = {
                ...userDetailState.details[userId],
                ...updatedUser,
            };
        }
    },

    removeUser: (userId: string) => {
        userState.users = userState.users.filter((user) => user.id !== userId);
        userState.totalCount = Math.max(0, userState.totalCount - 1);

        // Clean up detail cache
        delete userDetailState.details[userId];
        delete userDetailState.loading[userId];
        delete userDetailState.errors[userId];
    },

    setLoading: (loading: boolean) => {
        userState.loading = loading;
    },

    setError: (error: string | null) => {
        userState.error = error;
        userState.loading = false;
    },

    clearError: () => {
        userState.error = null;
    },

    // User detail operations
    getUserDetail: (userId: string): User | null => {
        return userDetailState.details[userId] || null;
    },

    setUserDetail: (userId: string, user: User) => {
        userDetailState.details[userId] = user;
        userDetailState.loading[userId] = false;
        userDetailState.errors[userId] = null;
    },

    setUserDetailLoading: (userId: string, loading: boolean) => {
        userDetailState.loading[userId] = loading;
        if (loading) {
            userDetailState.errors[userId] = null;
        }
    },

    setUserDetailError: (userId: string, error: string | null) => {
        userDetailState.errors[userId] = error;
        userDetailState.loading[userId] = false;
    },

    getUserDetailLoading: (userId: string): boolean => {
        return userDetailState.loading[userId] || false;
    },

    getUserDetailError: (userId: string): string | null => {
        return userDetailState.errors[userId] || null;
    },

    // SSR hydration methods
    hydrateUsers(
        users: User[],
        totalCount: number,
        page: number,
        pageSize: number,
        totalPages: number,
        searchQuery: string | null = null
    ) {
        this.setUsers(users, totalCount, page, pageSize, totalPages, searchQuery);
    },

    hydrateUserDetail(userId: string, user: User) {
        this.setUserDetail(userId, user);
    },

    // Clear all state
    clear() {
        userState.users = [];
        userState.loading = false;
        userState.error = null;
        userState.totalCount = 0;
        userState.page = 1;
        userState.pageSize = 20;
        userState.totalPages = 0;
        userState.searchQuery = null;
        userDetailState.details = {};
        userDetailState.loading = {};
        userDetailState.errors = {};
    },
};
