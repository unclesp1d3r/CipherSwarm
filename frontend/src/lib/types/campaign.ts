export type Campaign = {
    id: number;
    name: string;
    description?: string;
    status: 'pending' | 'active' | 'completed' | 'failed';
    created_at: string;
    updated_at: string;
    // Add other fields as needed from the API
};

// Campaign metrics interface
export interface CampaignMetrics {
    total_hashes: number;
    cracked_hashes: number;
    uncracked_hashes: number;
    percent_cracked: number;
    progress_percent: number;
}

// Campaign progress interface
export interface CampaignProgress {
    total_tasks: number;
    active_agents: number;
    completed_tasks: number;
    pending_tasks: number;
    active_tasks: number;
    failed_tasks: number;
    percentage_complete: number;
    overall_status: string | null;
    active_attack_id: number | null;
}
