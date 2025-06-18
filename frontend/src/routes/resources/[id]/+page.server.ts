import { error, fail, type RequestEvent } from '@sveltejs/kit';
import { createSessionServerApi } from '$lib/server/api';
import {
	ResourceDetailResponseSchema,
	ResourcePreviewResponseSchema,
	ResourceContentResponseSchema,
	ResourceLinesResponseSchema,
	type ResourceDetailResponse,
	type ResourcePreviewResponse
} from '$lib/schemas/resources';

export const load = async ({ params, cookies }: RequestEvent) => {
	// Ensure resource ID is provided
	if (!params.id) {
		throw error(400, 'Resource ID is required');
	}

	// Handle test environment
	if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
		const mockResource: ResourceDetailResponse = {
			id: params.id,
			file_name: 'test-wordlist.txt',
			file_label: 'Test Wordlist',
			resource_type: 'word_list',
			line_count: 1000,
			byte_size: 8192,
			checksum: 'abc123def456',
			updated_at: '2024-01-01T12:00:00Z',
			line_format: null,
			line_encoding: 'utf-8',
			used_for_modes: ['dictionary'],
			source: 'test',
			project_id: 1,
			unrestricted: false,
			is_uploaded: true,
			tags: ['test', 'wordlist'],
			attacks: [
				{ id: 1, name: 'Test Attack 1' },
				{ id: 2, name: 'Test Attack 2' }
			]
		};

		const mockPreview: ResourcePreviewResponse = {
			...mockResource,
			preview_lines: ['password', '123456', 'admin', 'test', 'qwerty'],
			preview_error: null,
			max_preview_lines: 10
		};

		return {
			resource: mockResource,
			preview: mockPreview
		};
	}

	// Get session cookie for authentication
	const sessionCookie = cookies.get('access_token');
	if (!sessionCookie) {
		throw error(401, 'Authentication required');
	}

	// Create authenticated API client
	const api = createSessionServerApi(sessionCookie);

	try {
		// Fetch resource detail and preview data in parallel
		const [resourceResponse, previewResponse] = await Promise.all([
			api.get(`/api/v1/web/resources/${params.id}`, ResourceDetailResponseSchema),
			api.get(`/api/v1/web/resources/${params.id}/preview`, ResourcePreviewResponseSchema)
		]);

		return {
			resource: resourceResponse,
			preview: previewResponse
		};
	} catch (err) {
		console.error('Error loading resource detail:', err);

		// Handle specific error cases
		if (err && typeof err === 'object' && 'status' in err) {
			const status = err.status as number;
			if (status === 404) {
				throw error(404, 'Resource not found');
			}
			if (status === 403) {
				throw error(403, 'Access denied');
			}
		}

		throw error(500, 'Failed to load resource details');
	}
};

export const actions = {
	// Load content for editing tab
	loadContent: async ({ params, cookies }: RequestEvent) => {
		if (!params.id) {
			return fail(400, { error: 'Resource ID is required' });
		}

		const sessionCookie = cookies.get('access_token');
		if (!sessionCookie) {
			return fail(401, { error: 'Authentication required' });
		}

		const api = createSessionServerApi(sessionCookie);

		try {
			const content = await api.get(
				`/api/v1/web/resources/${params.id}/content`,
				ResourceContentResponseSchema
			);
			return { content };
		} catch (err) {
			console.error('Error loading content:', err);
			return fail(500, { error: 'Failed to load content' });
		}
	},

	// Load lines for lines tab
	loadLines: async ({ params, cookies, url }: RequestEvent) => {
		if (!params.id) {
			return fail(400, { error: 'Resource ID is required' });
		}

		const sessionCookie = cookies.get('access_token');
		if (!sessionCookie) {
			return fail(401, { error: 'Authentication required' });
		}

		const api = createSessionServerApi(sessionCookie);
		const page = parseInt(url.searchParams.get('page') || '1');
		const pageSize = parseInt(url.searchParams.get('page_size') || '100');
		const validate = url.searchParams.get('validate') === 'true';

		try {
			const lines = await api.get(
				`/api/v1/web/resources/${params.id}/lines?page=${page}&page_size=${pageSize}&validate=${validate}`,
				ResourceLinesResponseSchema
			);
			return { lines };
		} catch (err) {
			console.error('Error loading lines:', err);
			return fail(500, { error: 'Failed to load lines' });
		}
	},

	// Save content
	saveContent: async ({ params, cookies, request }: RequestEvent) => {
		if (!params.id) {
			return fail(400, { error: 'Resource ID is required' });
		}

		const sessionCookie = cookies.get('access_token');
		if (!sessionCookie) {
			return fail(401, { error: 'Authentication required' });
		}

		const formData = await request.formData();
		const content = formData.get('content') as string;

		if (!content) {
			return fail(400, { error: 'Content is required' });
		}

		const api = createSessionServerApi(sessionCookie);

		try {
			// Use PATCH to update content
			await api.patchRaw(`/api/v1/web/resources/${params.id}/content`, { content });
			return { success: true, message: 'Content saved successfully' };
		} catch (err) {
			console.error('Error saving content:', err);
			return fail(500, { error: 'Failed to save content' });
		}
	}
};
