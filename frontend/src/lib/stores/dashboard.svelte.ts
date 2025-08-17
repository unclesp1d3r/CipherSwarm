/**
 * Dashboard store for managing real-time dashboard data
 * Integrates with SSE for live updates and API fetching
 */

import { browser } from '$app/environment';
import type { CampaignRead } from '$lib/schemas/campaigns';
import type { DashboardSummary } from '$lib/schemas/dashboard';
import { dashboardEvents } from '$lib/services/sse';
import { get } from 'svelte/store';

interface DashboardState {
    summary: DashboardSummary | null;
    campaigns: CampaignRead[];
    lastUpdated: Date | null;
    isLoading: boolean;
    error: string | null;
}

class DashboardStore {
    private state = $state<DashboardState>({
        summary: null,
        campaigns: [],
        lastUpdated: null,
        isLoading: false,
        error: null,
    });

    // Getters using $derived
    get summary() {
        return this.state.summary;
    }

    get campaigns() {
        return this.state.campaigns;
    }

    get lastUpdated() {
        return this.state.lastUpdated;
    }

    get isLoading() {
        return this.state.isLoading;
    }

    get error() {
        return this.state.error;
    }

    get isStale() {
        if (!this.state.lastUpdated) return false;
        const thirtySecondsAgo = new Date(Date.now() - 30 * 1000);
        return this.state.lastUpdated < thirtySecondsAgo;
    }

    /**
     * Initialize dashboard store with SSR data
     */
    initialize(summary: DashboardSummary, campaigns: CampaignRead[]) {
        this.state.summary = summary;
        this.state.campaigns = campaigns;
        this.state.lastUpdated = new Date();
        this.state.error = null;

        // Set up SSE event listener for real-time updates
        if (browser) {
            this.setupSSEListener();
        }
    }

    /**
     * Refresh dashboard data from API
     */
    async refreshData() {
        if (!browser) return;

        this.state.isLoading = true;
        this.state.error = null;

        try {
            // Fetch dashboard summary
            const summaryResponse = await fetch('/api/v1/web/dashboard/summary', {
                credentials: 'include',
            });

            if (!summaryResponse.ok) {
                throw new Error(`Dashboard API error: ${summaryResponse.status}`);
            }

            const summary: DashboardSummary = await summaryResponse.json();

            // Fetch campaigns
            const campaignsResponse = await fetch('/api/v1/web/campaigns?page=1&size=10', {
                credentials: 'include',
            });

            let campaigns: CampaignRead[] = [];
            if (campaignsResponse.ok) {
                const campaignsData = await campaignsResponse.json();
                campaigns = campaignsData.items || [];
            }

            // Update state
            this.state.summary = summary;
            this.state.campaigns = campaigns;
            this.state.lastUpdated = new Date();
            this.state.error = null;
        } catch (error) {
            console.error('Failed to refresh dashboard data:', error);
            this.state.error = error instanceof Error ? error.message : 'Unknown error';
        } finally {
            this.state.isLoading = false;
        }
    }

    /**
     * Set up SSE event listener for real-time updates
     */
    private setupSSEListener() {
        // Listen for dashboard events and trigger refresh
        $effect(() => {
            const events = get(dashboardEvents);
            if (events.length > 0) {
                const latestEvent = events[0];

                // Only refresh if the event is newer than our last update
                if (this.state.lastUpdated) {
                    const eventTime = new Date(latestEvent.timestamp);
                    if (eventTime > this.state.lastUpdated) {
                        console.log('Dashboard SSE trigger received, refreshing data');
                        this.refreshData();
                    }
                }
            }
        });
    }

    /**
     * Update specific agent metrics (for real-time agent updates)
     */
    updateAgentMetrics(activeAgents: number, totalAgents: number) {
        if (this.state.summary) {
            this.state.summary = {
                ...this.state.summary,
                active_agents: activeAgents,
                total_agents: totalAgents,
            };
            this.state.lastUpdated = new Date();
        }
    }

    /**
     * Update task metrics (for real-time task updates)
     */
    updateTaskMetrics(runningTasks: number, totalTasks: number) {
        if (this.state.summary) {
            this.state.summary = {
                ...this.state.summary,
                running_tasks: runningTasks,
                total_tasks: totalTasks,
            };
            this.state.lastUpdated = new Date();
        }
    }

    /**
     * Update crack metrics (for real-time crack updates)
     */
    updateCrackMetrics(recentlyCrackedHashes: number) {
        if (this.state.summary) {
            this.state.summary = {
                ...this.state.summary,
                recently_cracked_hashes: recentlyCrackedHashes,
            };
            this.state.lastUpdated = new Date();
        }
    }

    /**
     * Clear error state
     */
    clearError() {
        this.state.error = null;
    }

    /**
     * Reset store state
     */
    reset() {
        this.state = {
            summary: null,
            campaigns: [],
            lastUpdated: null,
            isLoading: false,
            error: null,
        };
    }
}

// Export singleton dashboard store
export const dashboardStore = new DashboardStore();
