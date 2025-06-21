import {
    UserSession,
    LoginResult,
    Body_login_api_v1_web_auth_login_post,
    ContextResponse,
    SetContextRequest,
    ChangePasswordRequest,
    RefreshTokenRequest,
} from '$lib/schemas/auth';
import { goto } from '$app/navigation';
import { browser } from '$app/environment';

// Authentication state
const authState = $state({
    user: null as UserSession | null,
    loading: false,
    error: null as string | null,
    isAuthenticated: false,
});

// Derived state
const currentUser = $derived(authState.user);
const isAdmin = $derived(authState.user?.role === 'admin');
const isProjectAdmin = $derived(authState.user?.role === 'project_admin' || isAdmin);
const currentProject = $derived(
    authState.user?.projects?.find((p) => p.id === authState.user?.current_project_id)
);

// Token refresh function
async function refreshSession(): Promise<boolean> {
    if (!browser) return false;

    try {
        const response = await fetch('/api/v1/web/auth/refresh', {
            method: 'POST',
            credentials: 'include',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify({ auto_refresh: true }),
        });

        if (response.ok) {
            const data = await response.json();
            const loginResult = LoginResult.parse(data);

            if (loginResult.message === 'Token refreshed successfully.') {
                // Get updated user context after refresh
                const contextResponse = await fetch('/api/v1/web/auth/me', {
                    credentials: 'include',
                });

                if (contextResponse.ok) {
                    const contextData = ContextResponse.parse(await contextResponse.json());
                    authState.user = {
                        id: contextData.user.id,
                        email: contextData.user.email,
                        name: contextData.user.name,
                        role: contextData.user.role as UserSession['role'],
                        projects: contextData.available_projects.map((p) => ({
                            id: p.id,
                            name: p.name,
                            role: 'member', // Default role, should be enhanced with actual role data
                        })),
                        current_project_id: contextData.active_project?.id,
                        is_authenticated: true,
                    };
                    authState.isAuthenticated = true;
                    return true;
                }
            }
        }
    } catch (error) {
        console.error('Token refresh failed:', error);
    }

    return false;
}

// Automatic token refresh setup
if (browser) {
    // Check session every 5 minutes
    setInterval(
        async () => {
            if (authState.isAuthenticated) {
                const refreshed = await refreshSession();
                if (!refreshed) {
                    // Session expired, redirect to login
                    authState.user = null;
                    authState.isAuthenticated = false;
                    goto('/login');
                }
            }
        },
        5 * 60 * 1000
    ); // 5 minutes
}

// Authentication store
export const authStore = {
    // Getters for reactive state
    get user() {
        return currentUser;
    },
    get loading() {
        return authState.loading;
    },
    get error() {
        return authState.error;
    },
    get isAuthenticated() {
        return authState.isAuthenticated;
    },
    get isAdmin() {
        return isAdmin;
    },
    get isProjectAdmin() {
        return isProjectAdmin;
    },
    get currentProject() {
        return currentProject;
    },

    // Actions
    setUser(user: UserSession) {
        authState.user = user;
        authState.isAuthenticated = true;
        authState.error = null;
    },

    setLoading(loading: boolean) {
        authState.loading = loading;
    },

    setError(error: string | null) {
        authState.error = error;
    },

    async login(email: string, password: string, remember: boolean = false): Promise<boolean> {
        if (!browser) return false;

        authState.loading = true;
        authState.error = null;

        try {
            // Validate input data
            const loginData = Body_login_api_v1_web_auth_login_post.parse({
                email,
                password,
            });

            // Create form data as expected by the FastAPI endpoint
            const formData = new FormData();
            formData.append('email', loginData.email);
            formData.append('password', loginData.password);

            const response = await fetch('/api/v1/web/auth/login', {
                method: 'POST',
                credentials: 'include',
                body: formData,
            });

            const data = await response.json();

            if (response.ok) {
                const loginResult = LoginResult.parse(data);

                if (loginResult.message === 'Login successful.') {
                    // Login successful, now get user context
                    const authSuccess = await this.checkAuth();
                    if (authSuccess) {
                        return true;
                    } else {
                        authState.error = 'Login succeeded but failed to get user data';
                        return false;
                    }
                } else {
                    authState.error = loginResult.message;
                    return false;
                }
            } else {
                authState.error = data.detail || data.error || 'Login failed';
                return false;
            }
        } catch (error) {
            if (error instanceof Error) {
                authState.error = error.message;
            } else {
                authState.error = 'Network error. Please try again.';
            }
            return false;
        } finally {
            authState.loading = false;
        }
    },

    async logout(): Promise<void> {
        if (!browser) return;

        try {
            await fetch('/api/v1/web/auth/logout', {
                method: 'POST',
                credentials: 'include',
            });
        } catch (error) {
            console.error('Logout API call failed:', error);
        } finally {
            // Clear state regardless of API response
            authState.user = null;
            authState.isAuthenticated = false;
            authState.error = null;
            goto('/login');
        }
    },

    async switchProject(projectId: number): Promise<boolean> {
        if (!browser || !authState.user) return false;

        try {
            const requestData = SetContextRequest.parse({ project_id: projectId });

            const response = await fetch('/api/v1/web/auth/context', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                credentials: 'include',
                body: JSON.stringify(requestData),
            });

            if (response.ok) {
                const contextData = ContextResponse.parse(await response.json());

                // Update user with new context
                authState.user = {
                    ...authState.user,
                    current_project_id: contextData.active_project?.id,
                    projects: contextData.available_projects.map((p) => ({
                        id: p.id,
                        name: p.name,
                        role:
                            authState.user?.projects?.find((up) => up.id === p.id)?.role ||
                            'member',
                    })),
                };
                return true;
            }
        } catch (error) {
            console.error('Project switch failed:', error);
        }

        return false;
    },

    async changePassword(
        oldPassword: string,
        newPassword: string,
        confirmPassword: string
    ): Promise<boolean> {
        if (!browser) return false;

        try {
            const requestData = ChangePasswordRequest.parse({
                old_password: oldPassword,
                new_password: newPassword,
                new_password_confirm: confirmPassword,
            });

            const response = await fetch('/api/v1/web/auth/change_password', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                credentials: 'include',
                body: JSON.stringify(requestData),
            });

            if (response.ok) {
                const result = LoginResult.parse(await response.json());
                return result.message === 'Password changed successfully.';
            }
        } catch (error) {
            console.error('Password change failed:', error);
        }

        return false;
    },

    // Check authentication status
    async checkAuth(): Promise<boolean> {
        if (!browser) return false;

        try {
            const response = await fetch('/api/v1/web/auth/me', {
                credentials: 'include',
            });

            if (response.ok) {
                const contextData = ContextResponse.parse(await response.json());

                authState.user = {
                    id: contextData.user.id,
                    email: contextData.user.email,
                    name: contextData.user.name,
                    role: contextData.user.role as UserSession['role'],
                    projects: contextData.available_projects.map((p) => ({
                        id: p.id,
                        name: p.name,
                        role: 'member', // Default role, should be enhanced with actual role data
                    })),
                    current_project_id: contextData.active_project?.id,
                    is_authenticated: true,
                };
                authState.isAuthenticated = true;
                return true;
            }
        } catch (error) {
            console.error('Auth check failed:', error);
        }

        authState.user = null;
        authState.isAuthenticated = false;
        return false;
    },

    // Hydrate from SSR data
    hydrate(user: UserSession | null) {
        if (user) {
            authState.user = user;
            authState.isAuthenticated = true;
        } else {
            authState.user = null;
            authState.isAuthenticated = false;
        }
        authState.loading = false;
        authState.error = null;
    },

    // Check permissions
    hasProjectAccess(projectId: number): boolean {
        if (!authState.user) return false;
        if (authState.user.role === 'admin') return true;
        return authState.user.projects?.some((p) => p.id === projectId) || false;
    },

    hasProjectAdminAccess(projectId: number): boolean {
        if (!authState.user) return false;
        if (authState.user.role === 'admin') return true;
        const project = authState.user.projects?.find((p) => p.id === projectId);
        return project?.role === 'project_admin';
    },
};
