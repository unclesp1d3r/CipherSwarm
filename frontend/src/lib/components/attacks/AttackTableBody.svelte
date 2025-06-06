<script lang="ts">
	import { Button } from '$lib/components/ui/button';
	import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
	import { MoreHorizontal } from '@lucide/svelte';

	interface Attack {
		id: string;
		name: string;
		type_label: string;
		length_range?: string;
		settings_summary: string;
		keyspace?: number;
		complexity_score?: number;
		comment?: string;
		type?: string;
		type_badge?: {
			color: string;
			label: string;
		};
	}

	interface Props {
		attacks: Attack[];
		onMoveAttack?: (attackId: string, direction: 'up' | 'down' | 'top' | 'bottom') => void;
		onEditAttack?: (attackId: string) => void;
		onDeleteAttack?: (attackId: string) => void;
		onDuplicateAttack?: (attackId: string) => void;
	}

	let { attacks, onMoveAttack, onEditAttack, onDeleteAttack, onDuplicateAttack }: Props =
		$props();

	function moveAttack(attackId: string, direction: 'up' | 'down' | 'top' | 'bottom') {
		onMoveAttack?.(attackId, direction);
	}

	function formatNumber(num: number | undefined): string {
		if (num === undefined) return '-';
		return new Intl.NumberFormat().format(num);
	}

	function renderComplexityDots(score: number | undefined): { filled: number; empty: number } {
		const safeScore = score || 0;
		return {
			filled: Math.min(safeScore, 5),
			empty: Math.max(0, 5 - safeScore)
		};
	}
</script>

{#each attacks as attack (attack.id)}
	<tr
		class="border-b bg-white dark:border-gray-700 dark:bg-gray-800"
		data-testid="attack-row-{attack.id}"
	>
		<td class="px-4 py-2 font-medium text-gray-900 dark:text-white">
			{#if attack.type_badge}
				<span
					class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium text-white {attack
						.type_badge.color}"
				>
					{attack.type_badge.label}
				</span>
			{:else}
				{attack.name}
			{/if}
		</td>
		<td class="px-4 py-2">{attack.type_label}</td>
		<td class="px-4 py-2">{attack.length_range ?? '-'}</td>
		<td class="px-4 py-2">{attack.settings_summary}</td>
		<td class="px-4 py-2">{formatNumber(attack.keyspace)}</td>
		<td class="px-4 py-2">
			{#if attack.complexity_score}
				<div class="flex space-x-1">
					{#each Array(renderComplexityDots(attack.complexity_score).filled) as _, i (i)}
						<span class="h-2 w-2 rounded-full bg-gray-600"></span>
					{/each}
					{#each Array(renderComplexityDots(attack.complexity_score).empty) as _, i (i + renderComplexityDots(attack.complexity_score).filled)}
						<span class="h-2 w-2 rounded-full bg-gray-200"></span>
					{/each}
				</div>
			{:else}
				-
			{/if}
		</td>
		<td class="px-4 py-2">{attack.comment || '-'}</td>
		<td class="px-4 py-2">
			<DropdownMenu.Root>
				<DropdownMenu.Trigger>
					{#snippet child({ props })}
						<Button
							{...props}
							variant="ghost"
							size="sm"
							class="h-8 w-8 p-0"
							aria-label="Open menu for {attack.name}"
							data-testid="attack-menu-{attack.id}"
						>
							<MoreHorizontal class="h-4 w-4" />
						</Button>
					{/snippet}
				</DropdownMenu.Trigger>
				<DropdownMenu.Content align="end">
					<DropdownMenu.Item onclick={() => onEditAttack?.(attack.id)}>
						Edit
					</DropdownMenu.Item>
					<DropdownMenu.Item onclick={() => onDuplicateAttack?.(attack.id)}>
						Duplicate
					</DropdownMenu.Item>
					<DropdownMenu.Separator />
					<DropdownMenu.Item onclick={() => moveAttack(attack.id, 'up')}>
						Move Up
					</DropdownMenu.Item>
					<DropdownMenu.Item onclick={() => moveAttack(attack.id, 'down')}>
						Move Down
					</DropdownMenu.Item>
					<DropdownMenu.Item onclick={() => moveAttack(attack.id, 'top')}>
						Move to Top
					</DropdownMenu.Item>
					<DropdownMenu.Item onclick={() => moveAttack(attack.id, 'bottom')}>
						Move to Bottom
					</DropdownMenu.Item>
					<DropdownMenu.Separator />
					<DropdownMenu.Item
						onclick={() => onDeleteAttack?.(attack.id)}
						class="text-red-600 focus:text-red-600"
					>
						Remove
					</DropdownMenu.Item>
				</DropdownMenu.Content>
			</DropdownMenu.Root>
		</td>
	</tr>
{/each}
