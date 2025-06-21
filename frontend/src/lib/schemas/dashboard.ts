/**
 * Dashboard schemas for CipherSwarm
 * Used by /api/v1/web/dashboard/* endpoints
 */

import { z } from 'zod';

// Dashboard summary
export const DashboardSummary = z.object({
    total_agents: z.number(),
    active_agents: z.number(),
    total_campaigns: z.number(),
    active_campaigns: z.number(),
    total_hash_lists: z.number(),
    total_hashes: z.number(),
    cracked_hashes: z.number(),
    crack_rate_percentage: z.number(),
});
export type DashboardSummary = z.infer<typeof DashboardSummary>;

// Recent activity
export const RecentActivityStats = z.object({
    recent_cracks: z.number(),
    recent_campaigns: z.number(),
    recent_agents: z.number(),
});
export type RecentActivityStats = z.infer<typeof RecentActivityStats>;

// Queue status
export const QueueStatus = z.object({
    high_priority: z.number(),
    normal_priority: z.number(),
    low_priority: z.number(),
    total_pending: z.number(),
    processing: z.number(),
});
export type QueueStatus = z.infer<typeof QueueStatus>;

export const QueueStatusResponse = z.object({
    queues: z.record(QueueStatus),
    total_pending: z.number(),
    total_processing: z.number(),
    recent_activity: RecentActivityStats,
});
export type QueueStatusResponse = z.infer<typeof QueueStatusResponse>;
