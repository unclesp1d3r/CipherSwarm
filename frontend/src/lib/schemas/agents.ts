/**
 * Agent schemas for CipherSwarm
 * Used by /api/v1/web/agents/* endpoints
 */

import { z } from 'zod';
import { AgentState, AgentType, OperatingSystemEnum, DeviceStatus } from './base';

// Core agent schemas
/**
 * Agent output schema
 * Complete agent information including configuration and status
 */
export const AgentOut = z.object({
    id: z.number().describe('Agent ID'),
    host_name: z.string().describe('Agent name'),
    client_signature: z.string().describe('Client signature for identification'),
    custom_label: z.string().optional().describe('Custom label for the agent'),
    state: AgentState.describe('Current agent state'),
    enabled: z.boolean().describe('Whether the agent is enabled'),
    advanced_configuration: z
        .record(z.unknown())
        .optional()
        .describe('Advanced configuration settings'),
    devices: z.array(z.string()).describe('Available compute devices'),
    agent_type: AgentType.optional().describe('Agent type'),
    operating_system: OperatingSystemEnum.describe('Operating system'),
    created_at: z.string().describe('Creation timestamp'),
    updated_at: z.string().describe('Last update timestamp'),
    last_seen_at: z.string().optional().describe('Last seen timestamp'),
    last_ipaddress: z.string().optional().describe('Last IP address'),
    projects: z.array(z.unknown()).optional().describe('Projects associated with the agent'),
});
export type AgentOut = z.infer<typeof AgentOut>;

/**
 * Agent list output schema
 * Simplified agent information for list views
 */
export const AgentListOut = z.object({
    items: z.array(AgentOut),
    total: z.number().describe('Total number of agents'),
    page: z.number().optional().describe('Page number'),
    page_size: z.number().optional().describe('Page size'),
    search: z.string().optional().describe('Search query'),
    state: z.string().optional().describe('Current agent state'),
});
export type AgentListOut = z.infer<typeof AgentListOut>;

/**
 * Agent dropdown item schema
 * Minimal agent information for dropdown selections
 */
export const AgentDropdownItem = z.object({
    id: z.number().describe('Agent ID'),
    display_name: z.string().describe('Agent name'),
    state: AgentState.describe('Current agent state'),
});
export type AgentDropdownItem = z.infer<typeof AgentDropdownItem>;

// Agent configuration schemas
/**
 * Advanced agent configuration schema
 * Detailed configuration options for agent behavior and performance
 */
export const AdvancedAgentConfiguration = z.object({
    agent_update_interval: z
        .number()
        .optional()
        .describe('The interval in seconds to check for agent updates'),
    use_native_hashcat: z
        .boolean()
        .optional()
        .describe('Use the hashcat binary already installed on the client system'),
    backend_device: z
        .string()
        .optional()
        .describe('The device to use for hashcat, separated by commas'),
    opencl_devices: z
        .string()
        .optional()
        .describe('The OpenCL device types to use for hashcat, separated by commas'),
    enable_additional_hash_types: z
        .boolean()
        .describe('Causes hashcat to perform benchmark-all, rather than just benchmark'),
    hwmon_temp_abort: z
        .number()
        .optional()
        .describe('Temperature abort threshold in Celsius for hashcat (--hwmon-temp-abort)'),
    backend_ignore_cuda: z
        .boolean()
        .optional()
        .describe('Ignore CUDA backend (--backend-ignore-cuda)'),
    backend_ignore_opencl: z
        .boolean()
        .optional()
        .describe('Ignore OpenCL backend (--backend-ignore-opencl)'),
    backend_ignore_hip: z
        .boolean()
        .optional()
        .describe('Ignore HIP backend (--backend-ignore-hip)'),
    backend_ignore_metal: z
        .boolean()
        .optional()
        .describe('Ignore Metal backend (--backend-ignore-metal)'),
});
export type AdvancedAgentConfiguration = z.infer<typeof AdvancedAgentConfiguration>;

// Benchmark schemas
/**
 * Hashcat benchmark schema
 * Individual benchmark result for a specific hash type
 */
export const HashcatBenchmark = z.object({
    hash_type: z.number().describe('Hashcat hash type number'),
    runtime: z.number().describe('Benchmark runtime in seconds'),
    hash_speed: z.number().describe('Benchmark speed in hashes per second'),
    device: z.number().describe('Device used for benchmark'),
});
export type HashcatBenchmark = z.infer<typeof HashcatBenchmark>;

/**
 * Agent benchmark schema
 * Collection of benchmark results for an agent
 */
export const AgentBenchmark = z.object({
    hashcat_benchmarks: z.array(HashcatBenchmark).describe('List of hashcat benchmark results'),
});
export type AgentBenchmark = z.infer<typeof AgentBenchmark>;

/**
 * Agent benchmark summary output schema
 * Organized benchmark results grouped by hash type
 */
export const AgentBenchmarkSummaryOut = z.object({
    benchmarks_by_hash_type: z
        .record(z.array(z.record(z.unknown())))
        .describe('Benchmarks organized by hash type'),
});
export type AgentBenchmarkSummaryOut = z.infer<typeof AgentBenchmarkSummaryOut>;

// Agent capabilities
/**
 * Agent capability device output schema
 * Information about a specific compute device available to an agent
 */
export const AgentCapabilityDeviceOut = z.object({
    device: z.string().describe('Device name'),
    hash_speed: z.number().describe('Benchmark speed in hashes per second'),
    runtime: z.number().describe('Benchmark runtime in seconds'),
    created_at: z.string().describe('Creation timestamp'),
});
export type AgentCapabilityDeviceOut = z.infer<typeof AgentCapabilityDeviceOut>;

/**
 * Agent capability output schema
 * Detailed capability information for an agent
 */
export const AgentCapabilityOut = z.object({
    hash_type_id: z.number().describe('Hash type ID'),
    hash_type_name: z.string().describe('Hash type name'),
    hash_type_description: z.string().optional().describe('Hash type description'),
    category: z.string().describe('Category'),
    speed: z.number().describe('Benchmark speed in hashes per second'),
    devices: z.array(AgentCapabilityDeviceOut).describe('Available devices'),
    last_benchmarked: z.string().describe('Last benchmark timestamp'),
});
export type AgentCapabilityOut = z.infer<typeof AgentCapabilityOut>;

/**
 * Agent capabilities output schema
 * Complete capabilities information including last benchmark date
 */
export const AgentCapabilitiesOut = z.object({
    agent_id: z.number().describe('Agent ID'),
    capabilities: z.array(AgentCapabilityOut).describe('List of agent capabilities'),
    last_benchmark: z.string().optional().describe('Last benchmark timestamp'),
});
export type AgentCapabilitiesOut = z.infer<typeof AgentCapabilitiesOut>;

// Agent monitoring and health
/**
 * Agent error log output schema
 * Error log entry for agent troubleshooting
 */
export const AgentErrorLogOut = z.object({
    errors: z.array(z.unknown()).describe('List of error entries'),
});
export type AgentErrorLogOut = z.infer<typeof AgentErrorLogOut>;

/**
 * Agent health summary schema
 * Health status and metrics for an agent
 */
export const AgentHealthSummary = z.object({
    total_agents: z.number().describe('Total number of agents'),
    online_agents: z.number().describe('Number of online agents'),
    total_campaigns: z.number().describe('Total number of campaigns'),
    total_tasks: z.number().describe('Total number of tasks'),
    total_hashlists: z.number().describe('Total number of hashlists'),
});
export type AgentHealthSummary = z.infer<typeof AgentHealthSummary>;

// Performance monitoring
/**
 * Device performance point schema
 * Single performance measurement for a device
 */
export const DevicePerformancePoint = z.object({
    timestamp: z.string().describe('Measurement timestamp'),
    speed: z.number().describe('Hash rate at this point'),
});
export type DevicePerformancePoint = z.infer<typeof DevicePerformancePoint>;

/**
 * Device performance series schema
 * Time series performance data for a device
 */
export const DevicePerformanceSeries = z.object({
    device: z.string().describe('Device name'),
    data: z.array(DevicePerformancePoint).describe('Performance data points'),
});
export type DevicePerformanceSeries = z.infer<typeof DevicePerformanceSeries>;

/**
 * Agent performance series output schema
 * Performance data for all devices on an agent
 */
export const AgentPerformanceSeriesOut = z.object({
    series: z.array(DevicePerformanceSeries).describe('Performance data for each device'),
});
export type AgentPerformanceSeriesOut = z.infer<typeof AgentPerformanceSeriesOut>;

// Agent testing and validation
/**
 * Agent presigned URL test request schema
 * Request to test agent's ability to access presigned URLs
 */
export const AgentPresignedUrlTestRequest = z.object({
    url: z.string().describe('Presigned URL to test'),
});
export type AgentPresignedUrlTestRequest = z.infer<typeof AgentPresignedUrlTestRequest>;

/**
 * Agent presigned URL test response schema
 * Result of presigned URL accessibility test
 */
export const AgentPresignedUrlTestResponse = z.object({
    valid: z.boolean().describe('Whether the test was successful'),
});
export type AgentPresignedUrlTestResponse = z.infer<typeof AgentPresignedUrlTestResponse>;

// Agent management responses
/**
 * Agent register modal context schema
 * Context information for agent registration modal
 */
export const AgentRegisterModalContext = z.object({
    agent: AgentOut,
    token: z.string().describe('Generated agent token'),
});
export type AgentRegisterModalContext = z.infer<typeof AgentRegisterModalContext>;

/**
 * Agent toggle enabled output schema
 * Response when enabling/disabling an agent
 */
export const AgentToggleEnabledOut = z.object({
    id: z.number().describe('Agent ID'),
    enabled: z.boolean().describe('New enabled state'),
});
export type AgentToggleEnabledOut = z.infer<typeof AgentToggleEnabledOut>;

/**
 * Agent update config output schema
 * Response when updating agent configuration
 */
export const AgentUpdateConfigOut = z.object({
    id: z.number().describe('Agent ID'),
    advanced_configuration: z.record(z.unknown()).describe('Advanced configuration settings'),
});
export type AgentUpdateConfigOut = z.infer<typeof AgentUpdateConfigOut>;

/**
 * Agent update devices output schema
 * Response when updating agent device configuration
 */
export const AgentUpdateDevicesOut = z.object({
    id: z.number().describe('Agent ID'),
    devices: z.array(z.string()).describe('List of updated devices'),
});
export type AgentUpdateDevicesOut = z.infer<typeof AgentUpdateDevicesOut>;

/**
 * Agent update hardware output schema
 * Response when updating agent hardware information
 */
export const AgentUpdateHardwareOut = z.object({
    id: z.number().describe('Agent ID'),
    hardware_info: z.record(z.unknown()).describe('Hardware information'),
});
export type AgentUpdateHardwareOut = z.infer<typeof AgentUpdateHardwareOut>;

// Form body schemas for API endpoints
/**
 * Register agent form body schema
 * Form data for agent registration endpoint
 */
export const Body_register_agent_api_v1_web_agents_post = z.object({
    name: z.string().describe('Agent name'),
    client_signature: z.string().optional().describe('Client signature for identification'),
    operating_system: OperatingSystemEnum.optional().describe('Operating system'),
    agent_type: AgentType.optional().describe('Agent type'),
});
export type Body_register_agent_api_v1_web_agents_post = z.infer<
    typeof Body_register_agent_api_v1_web_agents_post
>;

/**
 * Test agent presigned URL form body schema
 * Form data for testing agent presigned URL access
 */
export const Body_test_agent_presigned_url_api_v1_web_agents__agent_id__test_presigned_post =
    z.object({
        url: z.string().describe('Presigned URL to test'),
    });
export type Body_test_agent_presigned_url_api_v1_web_agents__agent_id__test_presigned_post =
    z.infer<typeof Body_test_agent_presigned_url_api_v1_web_agents__agent_id__test_presigned_post>;

/**
 * Toggle agent devices form body schema
 * Form data for enabling/disabling agent devices
 */
export const Body_toggle_agent_devices_api_v1_web_agents__agent_id__devices_patch = z.object({
    devices: z.array(z.string()).describe('List of device names to toggle'),
});
export type Body_toggle_agent_devices_api_v1_web_agents__agent_id__devices_patch = z.infer<
    typeof Body_toggle_agent_devices_api_v1_web_agents__agent_id__devices_patch
>;

/**
 * Update agent config form body schema
 * Form data for updating agent configuration
 */
export const Body_update_agent_config_api_v1_web_agents__agent_id__config_patch = z.object({
    advanced_configuration: z.record(z.unknown()).describe('Advanced configuration settings'),
});
export type Body_update_agent_config_api_v1_web_agents__agent_id__config_patch = z.infer<
    typeof Body_update_agent_config_api_v1_web_agents__agent_id__config_patch
>;

/**
 * Update agent hardware form body schema
 * Form data for updating agent hardware information
 */
export const Body_update_agent_hardware_api_v1_web_agents__agent_id__hardware_patch = z.object({
    hardware_info: z.record(z.unknown()).describe('Hardware information'),
});
export type Body_update_agent_hardware_api_v1_web_agents__agent_id__hardware_patch = z.infer<
    typeof Body_update_agent_hardware_api_v1_web_agents__agent_id__hardware_patch
>;
