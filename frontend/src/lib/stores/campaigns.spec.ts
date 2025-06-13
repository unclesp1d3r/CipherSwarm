import { describe, it, expect } from 'vitest';
import { campaigns } from './campaigns';
import type { Campaign } from '$lib/types/campaign';

describe('campaigns store', () => {
	it('should initialize as an empty array', () => {
		let value: Campaign[] = [
			{ id: 'dummy', name: 'dummy', status: 'pending', created_at: '', updated_at: '' }
		];
		const unsubscribe = campaigns.subscribe((v) => (value = v));
		expect(value).toEqual([]);
		unsubscribe();
	});

	it('should set campaigns', () => {
		const data: Campaign[] = [
			{ id: '1', name: 'Test', status: 'active', created_at: '', updated_at: '' }
		];
		campaigns.set(data);
		let value: Campaign[] = [];
		const unsubscribe = campaigns.subscribe((v) => (value = v));
		expect(value).toEqual(data);
		unsubscribe();
	});

	it('should update campaigns', () => {
		const data: Campaign[] = [
			{ id: '2', name: 'Another', status: 'completed', created_at: '', updated_at: '' }
		];
		campaigns.set([]);
		campaigns.update(() => data);
		let value: Campaign[] = [];
		const unsubscribe = campaigns.subscribe((v) => (value = v));
		expect(value).toEqual(data);
		unsubscribe();
	});
});
