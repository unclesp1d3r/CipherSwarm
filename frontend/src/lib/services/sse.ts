/**
 * Server-Sent Events (SSE) service for real-time updates
 * Provides lightweight trigger notifications for dashboard updates
 */

import { browser } from '$app/environment';
import { toast } from 'svelte-sonner';
import { writable } from 'svelte/store';

export interface SSEEvent {
    trigger: string;
    timestamp: string;
    target?: string;
    id?: number;
    project_id?: number;
}

export interface SSEConnection {
    connected: boolean;
    reconnectAttempts: number;
    maxReconnectAttempts: number;
    reconnectDelay: number;
    connectedEndpoints: Set<string>;
}

// Store for SSE connection status
export const sseConnectionStatus = writable<SSEConnection>({
    connected: false,
    reconnectAttempts: 0,
    maxReconnectAttempts: 5,
    reconnectDelay: 1000,
    connectedEndpoints: new Set(),
});

// Event stores for different SSE streams
export const dashboardEvents = writable<SSEEvent[]>([]);
export const campaignEvents = writable<SSEEvent[]>([]);
export const agentEvents = writable<SSEEvent[]>([]);
export const toastEvents = writable<SSEEvent[]>([]);

class SSEService {
    private connections: Map<string, EventSource> = new Map();
    private reconnectTimeouts: Map<string, NodeJS.Timeout> = new Map();

    /**
     * Connect to an SSE endpoint with automatic reconnection
     */
    connect(endpoint: string, onMessage: (event: SSEEvent) => void): void {
        if (!browser) return;

        // Close existing connection if any
        this.disconnect(endpoint);

        try {
            // Create EventSource with credentials for authentication
            // Note: In development, Vite proxy will forward cookies to backend
            const eventSource = new EventSource(endpoint, {
                withCredentials: true,
            });

            this.connections.set(endpoint, eventSource);

            eventSource.onopen = () => {
                console.log(`SSE connected to ${endpoint}`);
                this.updateConnectionStatus(endpoint, true);
            };

            eventSource.onmessage = (event) => {
                try {
                    const data: SSEEvent = JSON.parse(event.data);

                    // Handle ping/keepalive messages
                    if (data.trigger === 'ping') {
                        return;
                    }

                    onMessage(data);
                } catch (error) {
                    console.error('Failed to parse SSE message:', error);
                }
            };

            eventSource.onerror = (error) => {
                // Only treat as error if the connection is actually closed
                // EventSource.onerror can fire for transient issues during normal operation
                if (eventSource.readyState === EventSource.CLOSED) {
                    console.error(`SSE connection closed for ${endpoint}:`, error);
                    this.updateConnectionStatus(endpoint, false);
                    this.handleConnectionError(endpoint, onMessage);
                } else {
                    // For other states (CONNECTING, OPEN), just log but don't treat as failure
                    console.debug(`SSE transient error on ${endpoint} (state: ${eventSource.readyState}):`, error);
                }
            };
        } catch (error) {
            console.error(`Failed to connect to SSE endpoint ${endpoint}:`, error);
            this.handleConnectionError(endpoint, onMessage);
        }
    }

    /**
     * Update connection status for a specific endpoint
     */
    private updateConnectionStatus(endpoint: string, connected: boolean): void {
        sseConnectionStatus.update((status) => {
            const newConnectedEndpoints = new Set(status.connectedEndpoints);

            if (connected) {
                newConnectedEndpoints.add(endpoint);
            } else {
                newConnectedEndpoints.delete(endpoint);
            }

            return {
                ...status,
                connected: newConnectedEndpoints.size > 0,
                connectedEndpoints: newConnectedEndpoints,
                reconnectAttempts: connected ? 0 : status.reconnectAttempts,
            };
        });
    }

    /**
     * Disconnect from an SSE endpoint
     */
    disconnect(endpoint: string): void {
        const connection = this.connections.get(endpoint);
        if (connection) {
            connection.close();
            this.connections.delete(endpoint);
        }

        const timeout = this.reconnectTimeouts.get(endpoint);
        if (timeout) {
            clearTimeout(timeout);
            this.reconnectTimeouts.delete(endpoint);
        }

        this.updateConnectionStatus(endpoint, false);
    }

    /**
     * Disconnect all SSE connections
     */
    disconnectAll(): void {
        for (const endpoint of this.connections.keys()) {
            this.disconnect(endpoint);
        }
    }

    /**
     * Handle connection errors with exponential backoff reconnection
     */
    private handleConnectionError(endpoint: string, onMessage: (event: SSEEvent) => void): void {
        sseConnectionStatus.update((status) => {
            const newAttempts = status.reconnectAttempts + 1;

            if (newAttempts <= status.maxReconnectAttempts) {
                const delay = status.reconnectDelay * Math.pow(2, newAttempts - 1);

                console.log(
                    `SSE reconnecting to ${endpoint} in ${delay}ms (attempt ${newAttempts})`
                );

                const timeout = setTimeout(() => {
                    this.connect(endpoint, onMessage);
                }, delay);

                this.reconnectTimeouts.set(endpoint, timeout);
            } else {
                console.error(`SSE max reconnection attempts reached for ${endpoint}`);
                toast.error('Real-time updates disconnected. Please refresh the page.');
            }

            return {
                ...status,
                reconnectAttempts: newAttempts,
            };
        });
    }
}

// Singleton SSE service instance
export const sseService = new SSEService();

/**
 * Connect to dashboard SSE streams for real-time updates
 */
export function connectDashboardSSE(): void {
    if (!browser) return;

    // Add a small delay to ensure the page is fully loaded and authenticated
    setTimeout(() => {
        // Connect to campaign events for dashboard campaign overview updates
        sseService.connect('/api/v1/web/live/campaigns', (event) => {
            campaignEvents.update((events) => [event, ...events.slice(0, 99)]);

            // Trigger dashboard refresh for campaign updates
            if (event.trigger === 'refresh') {
                dashboardEvents.update((events) => [event, ...events.slice(0, 99)]);
            }
        });

        // Connect to agent events for dashboard agent metrics updates
        sseService.connect('/api/v1/web/live/agents', (event) => {
            agentEvents.update((events) => [event, ...events.slice(0, 99)]);

            // Trigger dashboard refresh for agent updates
            if (event.trigger === 'refresh') {
                dashboardEvents.update((events) => [event, ...events.slice(0, 99)]);
            }
        });

        // Connect to toast notifications
        sseService.connect('/api/v1/web/live/toasts', (event) => {
            toastEvents.update((events) => [event, ...events.slice(0, 99)]);

            // Show toast notification if it has a message
            if (event.trigger && event.trigger !== 'ping' && event.trigger !== 'refresh') {
                toast.success(event.trigger);
            }
        });
    }, 1000); // 1 second delay to ensure authentication is complete
}

/**
 * Disconnect from dashboard SSE streams
 */
export function disconnectDashboardSSE(): void {
    sseService.disconnectAll();
}
