export type Campaign = {
	id: string;
	name: string;
	description?: string;
	status: 'pending' | 'active' | 'completed' | 'failed';
	created_at: string;
	updated_at: string;
	// Add other fields as needed from the API
};
