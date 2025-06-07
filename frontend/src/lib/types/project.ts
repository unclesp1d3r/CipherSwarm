export interface Project {
	id: number;
	name: string;
	description: string | null;
	private: boolean;
	archived_at: string | null;
	notes: string | null;
	users: string[]; // UUIDs
	created_at: string;
	updated_at: string;
}

export interface ProjectCreate {
	name: string;
	description?: string | null;
	private?: boolean;
	archived_at?: string | null;
	notes?: string | null;
	users?: string[] | null;
}

export interface ProjectUpdate {
	name?: string | null;
	description?: string | null;
	private?: boolean | null;
	archived_at?: string | null;
	notes?: string | null;
	users?: string[] | null;
}

export interface ProjectListResponse {
	items: Project[];
	total: number;
	page: number;
	page_size: number;
	search?: string | null;
}
