<script lang="ts">
	import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '../ui/dialog';
	import { Card, CardHeader, CardContent } from '../ui/card';
	import { Switch } from '../ui/switch';
	import { Button } from '../ui/button';
	import { Input } from '../ui/input';
	import { Label } from '../ui/label';

	type AgentDevice = {
		id: string;
		name: string;
		type: string;
		enabled: boolean;
	};

	type AgentConfig = Record<string, string>;

	type Agent = {
		id: string;
		custom_label?: string;
		host_name: string;
		status: string;
		last_seen?: string;
		devices?: AgentDevice[];
		config?: AgentConfig;
	};

	export let agent: Agent | null = null;
	export let open: boolean = false;
	export let isAdmin: boolean = false;
	export let onClose: () => void;
	export let onSave: (payload: { id: string; custom_label: string; config: AgentConfig }) => void;
	export let onToggleDevice: (payload: {
		agentId: string;
		deviceId: string;
		enabled: boolean;
	}) => void;

	let localLabel: string = '';
	let localConfig: AgentConfig = {};
	let error: string | null = null;

	$: displayName = agent ? agent.custom_label || agent.host_name : '';

	$: if (agent) {
		localLabel = agent.custom_label || '';
		localConfig = { ...agent.config };
	} else {
		localLabel = '';
		localConfig = {};
	}
</script>

<Dialog {open}>
	<DialogContent class="w-full max-w-lg">
		<DialogHeader>
			<DialogTitle>Agent Details</DialogTitle>
		</DialogHeader>
		{#if !agent}
			<div class="text-muted-foreground py-8 text-center">No agent selected.</div>
		{:else}
			<Card class="mb-4">
				<CardHeader class="flex flex-col gap-2">
					<div class="flex items-center gap-2">
						<span class="text-lg font-semibold">{displayName}</span>
						<span
							class="ml-2 rounded px-2 py-1 text-xs {agent.status === 'online'
								? 'bg-green-100 text-green-800'
								: 'bg-gray-200 text-gray-600'}"
						>
							{agent.status === 'online' ? 'Online' : 'Offline'}
						</span>
					</div>
					<div class="text-muted-foreground text-xs">
						Last seen: {agent.last_seen || 'N/A'}
					</div>
				</CardHeader>
				<CardContent class="space-y-4">
					<form
						on:submit|preventDefault={() => {
							if (!agent) return;
							if (!displayName) {
								error = 'Agent must have a display name.';
								return;
							}
							onSave?.({
								id: agent.id,
								custom_label: localLabel,
								config: localConfig
							});
							error = null;
							onClose?.();
						}}
						class="space-y-4"
					>
						<div>
							<Label for="custom_label">Display Name</Label>
							<Input
								id="custom_label"
								type="text"
								bind:value={localLabel}
								placeholder={agent.host_name}
								disabled={!isAdmin}
							/>
						</div>
						{#if isAdmin}
							<div class="space-y-2">
								<Label>Device Toggles</Label>
								{#if agent.devices && agent.devices.length > 0}
									{#each agent.devices as device (device.id)}
										<div class="flex items-center gap-2">
											<span class="flex-1">{device.name} ({device.type})</span
											>
											<input
												type="checkbox"
												checked={device.enabled}
												on:change={(e) =>
													onToggleDevice?.({
														agentId: agent.id,
														deviceId: device.id,
														enabled: (e.target as HTMLInputElement)
															.checked
													})}
											/>
										</div>
									{/each}
								{:else}
									<div class="text-muted-foreground text-xs">
										No devices found.
									</div>
								{/if}
							</div>
							<div class="space-y-2">
								<Label>Advanced Config</Label>
								{#each Object.entries(localConfig) as [key] (key)}
									<div class="flex items-center gap-2">
										<Label class="flex-1">{key}</Label>
										<Input type="text" bind:value={localConfig[key]} />
									</div>
								{/each}
							</div>
						{/if}
						{#if error}
							<div class="text-sm text-red-600">{error}</div>
						{/if}
						<DialogFooter class="mt-4 flex justify-end gap-2">
							<button type="button" class="btn-secondary" on:click={onClose}
								>Cancel</button
							>
							{#if isAdmin}
								<Button type="submit">Save</Button>
							{/if}
						</DialogFooter>
					</form>
				</CardContent>
			</Card>
		{/if}
	</DialogContent>
</Dialog>

<style>
	/* Add any component-specific styles here if needed */
</style>
