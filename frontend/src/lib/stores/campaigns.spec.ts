import { describe, it, expect, beforeEach } from 'vitest';
import { get } from 'svelte/store';
import { campaigns, campaignsLoading, campaignsError, campaignsStore } from './campaigns';
import type { Campaign, CampaignMetrics, CampaignProgress } from '$lib/types/campaign';

describe('campaigns store', () => {
	beforeEach(() => {
		// Reset store state before each test by clearing all data
		campaignsStore.setCampaigns([]);
		campaignsStore.setLoading(false);
		campaignsStore.setError(null);
		// Clear any existing campaign data
		for (let i = 1; i <= 10; i++) {
			campaignsStore.setCampaignError(i, null);
			campaignsStore.setCampaignLoading(i, false);
		}
	});

	describe('basic campaign operations', () => {
		it('should set campaigns', () => {
			const testCampaigns: Campaign[] = [
				{
					id: 1,
					name: 'Test Campaign',
					status: 'active',
					created_at: '2023-01-01T00:00:00Z',
					updated_at: '2023-01-01T00:00:00Z'
				}
			];

			campaignsStore.setCampaigns(testCampaigns);
			expect(get(campaigns)).toEqual(testCampaigns);
			expect(get(campaignsLoading)).toBe(false);
			expect(get(campaignsError)).toBe(null);
		});

		it('should add a campaign', () => {
			const campaign: Campaign = {
				id: 1,
				name: 'New Campaign',
				status: 'pending',
				created_at: '2023-01-01T00:00:00Z',
				updated_at: '2023-01-01T00:00:00Z'
			};

			campaignsStore.addCampaign(campaign);
			expect(get(campaigns)).toContain(campaign);
		});

		it('should update a campaign', () => {
			const campaign: Campaign = {
				id: 1,
				name: 'Original Name',
				status: 'pending',
				created_at: '2023-01-01T00:00:00Z',
				updated_at: '2023-01-01T00:00:00Z'
			};

			campaignsStore.setCampaigns([campaign]);
			campaignsStore.updateCampaign(1, { name: 'Updated Name', status: 'active' });

			const updatedCampaigns = get(campaigns);
			expect(updatedCampaigns[0].name).toBe('Updated Name');
			expect(updatedCampaigns[0].status).toBe('active');
		});

		it('should remove a campaign', () => {
			const campaign: Campaign = {
				id: 1,
				name: 'To Remove',
				status: 'pending',
				created_at: '2023-01-01T00:00:00Z',
				updated_at: '2023-01-01T00:00:00Z'
			};

			campaignsStore.setCampaigns([campaign]);
			campaignsStore.removeCampaign(1);
			expect(get(campaigns)).toEqual([]);
		});
	});

	describe('loading and error states', () => {
		it('should set loading state', () => {
			campaignsStore.setLoading(true);
			expect(get(campaignsLoading)).toBe(true);

			campaignsStore.setLoading(false);
			expect(get(campaignsLoading)).toBe(false);
		});

		it('should set error state', () => {
			const error = 'Test error';
			campaignsStore.setError(error);
			expect(get(campaignsError)).toBe(error);

			campaignsStore.setError(null);
			expect(get(campaignsError)).toBe(null);
		});
	});

	describe('campaign data operations', () => {
		const testMetrics: CampaignMetrics = {
			total_hashes: 100,
			cracked_hashes: 25,
			uncracked_hashes: 75,
			percent_cracked: 25,
			progress_percent: 50
		};

		const testProgress: CampaignProgress = {
			total_tasks: 10,
			active_agents: 2,
			completed_tasks: 3,
			pending_tasks: 4,
			active_tasks: 2,
			failed_tasks: 1,
			percentage_complete: 30,
			overall_status: 'running',
			active_attack_id: 123
		};

		it('should set campaign metrics', () => {
			campaignsStore.setCampaignMetrics(1, testMetrics);
			expect(campaignsStore.getCampaignMetrics(1)).toEqual(testMetrics);
			expect(campaignsStore.isCampaignLoading(1)).toBe(false);
			expect(campaignsStore.getCampaignError(1)).toBe(null);
		});

		it('should set campaign progress', () => {
			campaignsStore.setCampaignProgress(1, testProgress);
			expect(campaignsStore.getCampaignProgress(1)).toEqual(testProgress);
			expect(campaignsStore.isCampaignLoading(1)).toBe(false);
			expect(campaignsStore.getCampaignError(1)).toBe(null);
		});

		it('should set campaign data (both metrics and progress)', () => {
			campaignsStore.setCampaignData(1, testMetrics, testProgress);
			expect(campaignsStore.getCampaignMetrics(1)).toEqual(testMetrics);
			expect(campaignsStore.getCampaignProgress(1)).toEqual(testProgress);
			expect(campaignsStore.isCampaignLoading(1)).toBe(false);
			expect(campaignsStore.getCampaignError(1)).toBe(null);
		});

		it('should set campaign loading state', () => {
			campaignsStore.setCampaignLoading(1, true);
			expect(campaignsStore.isCampaignLoading(1)).toBe(true);

			campaignsStore.setCampaignLoading(1, false);
			expect(campaignsStore.isCampaignLoading(1)).toBe(false);
		});

		it('should set campaign error', () => {
			const error = 'Campaign error';
			campaignsStore.setCampaignError(1, error);
			expect(campaignsStore.getCampaignError(1)).toBe(error);
			expect(campaignsStore.isCampaignLoading(1)).toBe(false);
		});

		it('should hydrate campaign data from SSR', () => {
			campaignsStore.hydrateCampaignData(1, testMetrics, testProgress);
			expect(campaignsStore.getCampaignMetrics(1)).toEqual(testMetrics);
			expect(campaignsStore.getCampaignProgress(1)).toEqual(testProgress);
		});

		it('should hydrate only metrics from SSR', () => {
			// Ensure clean state for campaign 2
			expect(campaignsStore.getCampaignMetrics(2)).toBe(null);
			expect(campaignsStore.getCampaignProgress(2)).toBe(null);

			campaignsStore.hydrateCampaignData(2, testMetrics);
			expect(campaignsStore.getCampaignMetrics(2)).toEqual(testMetrics);
			expect(campaignsStore.getCampaignProgress(2)).toBe(null);
		});

		it('should hydrate only progress from SSR', () => {
			// Ensure clean state for campaign 3
			expect(campaignsStore.getCampaignMetrics(3)).toBe(null);
			expect(campaignsStore.getCampaignProgress(3)).toBe(null);

			campaignsStore.hydrateCampaignData(3, undefined, testProgress);
			expect(campaignsStore.getCampaignMetrics(3)).toBe(null);
			expect(campaignsStore.getCampaignProgress(3)).toEqual(testProgress);
		});

		it('should clean up data when removing campaign', () => {
			const campaign: Campaign = {
				id: 1,
				name: 'Test Campaign',
				status: 'active',
				created_at: '2023-01-01T00:00:00Z',
				updated_at: '2023-01-01T00:00:00Z'
			};

			campaignsStore.setCampaigns([campaign]);
			campaignsStore.setCampaignData(1, testMetrics, testProgress);

			// Verify data is set
			expect(campaignsStore.getCampaignMetrics(1)).toEqual(testMetrics);
			expect(campaignsStore.getCampaignProgress(1)).toEqual(testProgress);

			// Remove campaign
			campaignsStore.removeCampaign(1);

			// Verify data is cleaned up
			expect(get(campaigns)).toEqual([]);
			expect(campaignsStore.getCampaignMetrics(1)).toBe(null);
			expect(campaignsStore.getCampaignProgress(1)).toBe(null);
			expect(campaignsStore.isCampaignLoading(1)).toBe(false);
			expect(campaignsStore.getCampaignError(1)).toBe(null);
		});
	});

	describe('getters', () => {
		it('should return null for non-existent campaign data', () => {
			expect(campaignsStore.getCampaignMetrics(999)).toBe(null);
			expect(campaignsStore.getCampaignProgress(999)).toBe(null);
			expect(campaignsStore.isCampaignLoading(999)).toBe(false);
			expect(campaignsStore.getCampaignError(999)).toBe(null);
		});
	});
});
