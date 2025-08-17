import type {
    ProjectRead,
    ProjectCreate,
    ProjectUpdate,
    ProjectListResponse,
} from '$lib/schemas/projects';

// Frontend project type with adapter properties for backward compatibility
// The backend uses different field names than some frontend components expect
export interface Project extends ProjectRead {
    // Add adapter properties that some frontend components expect
    owner_id?: string;
    is_archived: boolean;
    member_count?: number;
    campaign_count?: number;
}

// Transform function to convert backend ProjectRead to frontend Project
export function adaptProject(backendProject: ProjectRead): Project {
    return {
        ...backendProject,
        // Provide adapter properties for backward compatibility
        owner_id: backendProject.users[0] || undefined, // Use first user as owner
        is_archived: !!backendProject.archived_at, // Convert archived_at to boolean
        member_count: backendProject.users.length,
        campaign_count: undefined, // This would need to be provided separately
    };
}

// Re-export the schema types for consistency
export type { ProjectRead, ProjectCreate, ProjectUpdate, ProjectListResponse };

// The Project interface above already extends ProjectRead with backwards compatibility

// Additional frontend types for components
export interface ProjectSummary {
    id: number;
    name: string;
    description?: string;
    private: boolean;
    is_archived: boolean;
    user_count: number;
}
