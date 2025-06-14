import { z } from 'zod';

// Resource types enum matching backend
export const AttackResourceTypeSchema = z.enum([
	'mask_list',
	'rule_list',
	'word_list',
	'charset',
	'dynamic_word_list'
]);

export type AttackResourceType = z.infer<typeof AttackResourceTypeSchema>;

// Resource list item schema matching backend ResourceListItem/ResourceBase
export const ResourceListItemSchema = z.object({
	id: z.string().uuid(),
	file_name: z.string(),
	file_label: z.string().nullable(),
	resource_type: AttackResourceTypeSchema,
	line_count: z.number().nullable(),
	byte_size: z.number().nullable(),
	checksum: z.string(),
	updated_at: z.string().nullable(),
	line_format: z.string().nullable(),
	line_encoding: z.string().nullable(),
	used_for_modes: z.array(z.string()).nullable(),
	source: z.string().nullable(),
	project_id: z.number().nullable(),
	unrestricted: z.boolean().nullable(),
	is_uploaded: z.boolean(),
	tags: z.array(z.string()).nullable()
});

export type ResourceListItem = z.infer<typeof ResourceListItemSchema>;

// Paginated response schema matching backend ResourceListResponse
export const ResourceListResponseSchema = z.object({
	items: z.array(ResourceListItemSchema),
	total_count: z.number(),
	page: z.number(),
	page_size: z.number(),
	total_pages: z.number(),
	resource_type: AttackResourceTypeSchema.nullable()
});

export type ResourceListResponse = z.infer<typeof ResourceListResponseSchema>;

// Resource type options for UI
export const resourceTypes = [
	{ value: '', label: 'All Types' },
	{ value: 'mask_list', label: 'Mask List' },
	{ value: 'rule_list', label: 'Rule List' },
	{ value: 'word_list', label: 'Word List' },
	{ value: 'charset', label: 'Charset' },
	{ value: 'dynamic_word_list', label: 'Dynamic Word List' }
] as const;
