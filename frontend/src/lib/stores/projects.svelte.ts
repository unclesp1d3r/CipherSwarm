import type { Project } from '$lib/types/project';

// Store state interfaces
interface ProjectState {
    projects: Project[];
    loading: boolean;
    error: string | null;
    totalCount: number;
    page: number;
    pageSize: number;
    totalPages: number;
    searchQuery: string | null;
}

interface ProjectDetailState {
    details: Record<string, Project>;
    loading: Record<string, boolean>;
    errors: Record<string, string | null>;
}

interface ProjectContextState {
    activeProject: { id: number; name: string } | null;
    availableProjects: { id: number; name: string }[];
    user: {
        id: string;
        email: string;
        name: string;
        role: string;
    } | null;
    loading: boolean;
    error: string | null;
}

// Create reactive state using SvelteKit 5 runes
const projectState = $state<ProjectState>({
    projects: [],
    loading: false,
    error: null,
    totalCount: 0,
    page: 1,
    pageSize: 20,
    totalPages: 0,
    searchQuery: null,
});

const projectDetailState = $state<ProjectDetailState>({
    details: {},
    loading: {},
    errors: {},
});

const projectContextState = $state<ProjectContextState>({
    activeProject: null,
    availableProjects: [],
    user: null,
    loading: false,
    error: null,
});

// Derived stores at module level
const projects = $derived(projectState.projects);
const projectsLoading = $derived(projectState.loading);
const projectsError = $derived(projectState.error);
const projectsPagination = $derived({
    totalCount: projectState.totalCount,
    page: projectState.page,
    pageSize: projectState.pageSize,
    totalPages: projectState.totalPages,
    searchQuery: projectState.searchQuery,
});

const activeProject = $derived(projectContextState.activeProject);
const availableProjects = $derived(projectContextState.availableProjects);
const contextUser = $derived(projectContextState.user);
const contextLoading = $derived(projectContextState.loading);
const contextError = $derived(projectContextState.error);

// Export functions that return the derived values
export function getProjects() {
    return projects;
}

export function getProjectsLoading() {
    return projectsLoading;
}

export function getProjectsError() {
    return projectsError;
}

export function getProjectsPagination() {
    return projectsPagination;
}

export function getActiveProject() {
    return activeProject;
}

export function getAvailableProjects() {
    return availableProjects;
}

export function getContextUser() {
    return contextUser;
}

export function getContextLoading() {
    return contextLoading;
}

export function getContextError() {
    return contextError;
}

// Project store actions
export const projectsStore = {
    // Getters for reactive state
    get projects() {
        return projectState.projects;
    },
    get loading() {
        return projectState.loading;
    },
    get error() {
        return projectState.error;
    },
    get pagination() {
        return {
            totalCount: projectState.totalCount,
            page: projectState.page,
            pageSize: projectState.pageSize,
            totalPages: projectState.totalPages,
            searchQuery: projectState.searchQuery,
        };
    },
    get activeProject() {
        return projectContextState.activeProject;
    },
    get availableProjects() {
        return projectContextState.availableProjects;
    },
    get contextUser() {
        return projectContextState.user;
    },
    get contextLoading() {
        return projectContextState.loading;
    },
    get contextError() {
        return projectContextState.error;
    },

    // Basic project operations
    setProjects: (
        projects: Project[],
        totalCount: number,
        page: number,
        pageSize: number,
        totalPages: number,
        searchQuery: string | null = null
    ) => {
        projectState.projects = projects;
        projectState.totalCount = totalCount;
        projectState.page = page;
        projectState.pageSize = pageSize;
        projectState.totalPages = totalPages;
        projectState.searchQuery = searchQuery;
        projectState.loading = false;
        projectState.error = null;
    },

    addProject: (project: Project) => {
        projectState.projects = [...projectState.projects, project];
        projectState.totalCount = projectState.totalCount + 1;
    },

    updateProject: (projectId: number, updatedProject: Partial<Project>) => {
        projectState.projects = projectState.projects.map((project) =>
            project.id === projectId ? { ...project, ...updatedProject } : project
        );

        // Update detail cache if exists
        if (projectDetailState.details[projectId.toString()]) {
            projectDetailState.details[projectId.toString()] = {
                ...projectDetailState.details[projectId.toString()],
                ...updatedProject,
            };
        }
    },

    removeProject: (projectId: number) => {
        projectState.projects = projectState.projects.filter((project) => project.id !== projectId);
        projectState.totalCount = Math.max(0, projectState.totalCount - 1);

        // Clean up detail cache
        const projectIdStr = projectId.toString();
        delete projectDetailState.details[projectIdStr];
        delete projectDetailState.loading[projectIdStr];
        delete projectDetailState.errors[projectIdStr];
    },

    setLoading: (loading: boolean) => {
        projectState.loading = loading;
    },

    setError: (error: string | null) => {
        projectState.error = error;
        projectState.loading = false;
    },

    clearError: () => {
        projectState.error = null;
    },

    // Project detail operations
    getProjectDetail: (projectId: string): Project | null => {
        return projectDetailState.details[projectId] || null;
    },

    setProjectDetail: (projectId: string, project: Project) => {
        projectDetailState.details[projectId] = project;
        projectDetailState.loading[projectId] = false;
        projectDetailState.errors[projectId] = null;
    },

    setProjectDetailLoading: (projectId: string, loading: boolean) => {
        projectDetailState.loading[projectId] = loading;
        if (loading) {
            projectDetailState.errors[projectId] = null;
        }
    },

    setProjectDetailError: (projectId: string, error: string | null) => {
        projectDetailState.errors[projectId] = error;
        projectDetailState.loading[projectId] = false;
    },

    getProjectDetailLoading: (projectId: string): boolean => {
        return projectDetailState.loading[projectId] || false;
    },

    getProjectDetailError: (projectId: string): string | null => {
        return projectDetailState.errors[projectId] || null;
    },

    // Project context operations
    setProjectContext: (
        activeProject: { id: number; name: string } | null,
        availableProjects: { id: number; name: string }[],
        user: {
            id: string;
            email: string;
            name: string;
            role: string;
        } | null
    ) => {
        projectContextState.activeProject = activeProject;
        projectContextState.availableProjects = availableProjects;
        projectContextState.user = user;
        projectContextState.loading = false;
        projectContextState.error = null;
    },

    setActiveProject: (project: { id: number; name: string } | null) => {
        projectContextState.activeProject = project;
    },

    setContextLoading: (loading: boolean) => {
        projectContextState.loading = loading;
    },

    setContextError: (error: string | null) => {
        projectContextState.error = error;
        projectContextState.loading = false;
    },

    clearContextError: () => {
        projectContextState.error = null;
    },

    // SSR hydration methods
    hydrateProjects(
        projects: Project[],
        totalCount: number,
        page: number,
        pageSize: number,
        totalPages: number,
        searchQuery: string | null = null
    ) {
        this.setProjects(projects, totalCount, page, pageSize, totalPages, searchQuery);
    },

    hydrateProjectDetail(projectId: string, project: Project) {
        this.setProjectDetail(projectId, project);
    },

    hydrateProjectContext(
        activeProject: { id: number; name: string } | null,
        availableProjects: { id: number; name: string }[],
        user: {
            id: string;
            email: string;
            name: string;
            role: string;
        } | null
    ) {
        this.setProjectContext(activeProject, availableProjects, user);
    },

    // Clear all state
    clear() {
        projectState.projects = [];
        projectState.loading = false;
        projectState.error = null;
        projectState.totalCount = 0;
        projectState.page = 1;
        projectState.pageSize = 20;
        projectState.totalPages = 0;
        projectState.searchQuery = null;
        projectDetailState.details = {};
        projectDetailState.loading = {};
        projectDetailState.errors = {};
        projectContextState.activeProject = null;
        projectContextState.availableProjects = [];
        projectContextState.user = null;
        projectContextState.loading = false;
        projectContextState.error = null;
    },
};
