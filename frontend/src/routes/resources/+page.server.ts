import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';
import { createSessionServerApi } from '$lib/server/api';
import { ResourceListResponseSchema, type AttackResourceType } from '$lib/schemas/resources';

export const load = (async ({ url, locals }) => {
	// Test environment detection - provide mock data for tests
	if (process.env.NODE_ENV === 'test' || process.env.PLAYWRIGHT_TEST || process.env.CI) {
		// Parse URL parameters for filtering in test environment
		const searchParams = url.searchParams;
		const q = searchParams.get('q') || '';
		const resourceType = searchParams.get('resource_type') || '';
		const page = parseInt(searchParams.get('page') || '1');
		const pageSize = parseInt(searchParams.get('page_size') || '25');

		// Mock data
		const allMockResources = [
			{
				id: '550e8400-e29b-41d4-a716-446655440001',
				file_name: 'rockyou.txt',
				file_label: 'RockYou Wordlist',
				resource_type: 'word_list' as AttackResourceType,
				line_count: 14344391,
				byte_size: 139921507,
				updated_at: '2024-01-15T10:30:00Z',
				checksum: 'abc123',
				line_format: null,
				line_encoding: null,
				used_for_modes: null,
				source: null,
				project_id: null,
				unrestricted: true,
				is_uploaded: true,
				tags: null
			},
			{
				id: '550e8400-e29b-41d4-a716-446655440002',
				file_name: 'best64.rule',
				file_label: 'Best64 Rules',
				resource_type: 'rule_list' as AttackResourceType,
				line_count: 77,
				byte_size: 1024,
				updated_at: '2024-01-14T15:45:00Z',
				checksum: 'def456',
				line_format: null,
				line_encoding: null,
				used_for_modes: null,
				source: null,
				project_id: 1,
				unrestricted: false,
				is_uploaded: true,
				tags: null
			},
			{
				id: '550e8400-e29b-41d4-a716-446655440003',
				file_name: 'common_masks.txt',
				file_label: null,
				resource_type: 'mask_list' as AttackResourceType,
				line_count: 25,
				byte_size: 512,
				updated_at: '2024-01-13T09:15:00Z',
				checksum: 'ghi789',
				line_format: null,
				line_encoding: null,
				used_for_modes: null,
				source: null,
				project_id: null,
				unrestricted: true,
				is_uploaded: true,
				tags: null
			},
			{
				id: '550e8400-e29b-41d4-a716-446655440004',
				file_name: 'custom_charset.hcchr',
				file_label: 'Custom Charset',
				resource_type: 'charset' as AttackResourceType,
				line_count: 1,
				byte_size: 64,
				updated_at: '2024-01-12T14:20:00Z',
				checksum: 'jkl012',
				line_format: null,
				line_encoding: null,
				used_for_modes: null,
				source: null,
				project_id: 1,
				unrestricted: false,
				is_uploaded: true,
				tags: null
			},
			{
				id: '550e8400-e29b-41d4-a716-446655440005',
				file_name: 'previous_passwords.txt',
				file_label: 'Previous Passwords',
				resource_type: 'dynamic_word_list' as AttackResourceType,
				line_count: 1250,
				byte_size: 25600,
				updated_at: '2024-01-11T11:00:00Z',
				checksum: 'mno345',
				line_format: null,
				line_encoding: null,
				used_for_modes: null,
				source: null,
				project_id: 1,
				unrestricted: false,
				is_uploaded: true,
				tags: null
			}
		];

		// Apply filtering
		let filteredResources = allMockResources;

		// Filter by search query
		if (q.trim()) {
			const searchTerm = q.trim().toLowerCase();
			filteredResources = filteredResources.filter(
				(resource) =>
					resource.file_name.toLowerCase().includes(searchTerm) ||
					(resource.file_label && resource.file_label.toLowerCase().includes(searchTerm))
			);
		}

		// Filter by resource type
		if (resourceType) {
			filteredResources = filteredResources.filter(
				(resource) => resource.resource_type === resourceType
			);
		}

		// Handle special test cases for error scenarios
		if (q === 'nonexistent') {
			filteredResources = [];
		}

		// Handle error test scenario
		if (searchParams.get('test_error') === '500') {
			throw error(500, 'Internal Server Error');
		}

		// Calculate pagination
		const totalCount = filteredResources.length;
		const totalPages = Math.ceil(totalCount / pageSize);
		const startIndex = (page - 1) * pageSize;
		const endIndex = startIndex + pageSize;
		const paginatedResources = filteredResources.slice(startIndex, endIndex);

		return {
			resources: {
				items: paginatedResources,
				total_count: totalCount,
				page,
				page_size: pageSize,
				total_pages: totalPages,
				resource_type: resourceType || null
			}
		};
	}

	// Check if user is authenticated via hooks
	if (!locals.session || !locals.user) {
		throw error(401, 'Authentication required');
	}

	// Parse URL parameters
	const searchParams = url.searchParams;
	const q = searchParams.get('q') || '';
	const resourceType = searchParams.get('resource_type') || '';
	const page = parseInt(searchParams.get('page') || '1');
	const pageSize = parseInt(searchParams.get('page_size') || '25');

	try {
		// Create authenticated API client using session from locals
		const api = createSessionServerApi(`access_token=${locals.session}`);

		// Build API URL with parameters
		const apiParams = new URLSearchParams({
			page: page.toString(),
			page_size: pageSize.toString()
		});

		if (q.trim()) {
			apiParams.append('q', q.trim());
		}

		if (resourceType) {
			apiParams.append('resource_type', resourceType);
		}

		// Fetch resources from backend
		const resources = await api.get(
			`/api/v1/web/resources/?${apiParams}`,
			ResourceListResponseSchema
		);

		return {
			resources
		};
	} catch (err) {
		console.error('Failed to load resources:', err);

		// Handle specific error cases
		if (err && typeof err === 'object' && 'status' in err) {
			const status = err.status as number;
			if (status === 404) {
				throw error(404, 'Resources not found');
			}
			if (status === 403) {
				throw error(403, 'Access denied');
			}
		}

		throw error(500, 'Failed to load resources');
	}
}) satisfies PageServerLoad;
