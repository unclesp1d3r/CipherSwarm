<script lang="ts">
	import { type SuperForm } from 'sveltekit-superforms';
	import { type AttackFormData } from '$lib/schemas/attack.js';
	import {
		Card,
		CardContent,
		CardDescription,
		CardHeader,
		CardTitle
	} from '$lib/components/ui/card/index.js';
	import { Badge } from '$lib/components/ui/badge/index.js';
	import { Separator } from '$lib/components/ui/separator/index.js';
	import { CheckCircle, AlertCircle } from 'lucide-svelte';

	interface Props {
		form: SuperForm<AttackFormData>;
		wordlists: Array<{ id: string; name: string; line_count?: number }>;
		rulelists: Array<{ id: string; name: string; rule_count?: number }>;
	}

	let { form, wordlists, rulelists }: Props = $props();

	const { form: formData } = form;

	// Helper to get wordlist details
	function getWordlistDetails(id: string) {
		return wordlists.find((w) => w.id === id);
	}

	// Helper to get rulelist details
	function getRulelistDetails(id: string) {
		return rulelists.find((r) => r.id === id);
	}

	// Get attack mode display name
	function getAttackModeDisplay(mode: string) {
		switch (mode) {
			case 'dictionary':
				return 'Dictionary Attack';
			case 'mask':
				return 'Mask Attack';
			case 'brute_force':
				return 'Brute Force Attack';
			default:
				return mode;
		}
	}

	// Get character set display names
	function getCharsetDisplay(charset: string) {
		switch (charset) {
			case 'lowercase':
				return 'Lowercase (a-z)';
			case 'uppercase':
				return 'Uppercase (A-Z)';
			case 'digits':
				return 'Digits (0-9)';
			case 'symbols':
				return 'Symbols (!@#$...)';
			case 'space':
				return 'Space';
			default:
				return charset;
		}
	}

	// Check if configuration is complete
	const isComplete = $derived(() => {
		if (!$formData.name?.trim()) return false;
		if (!$formData.attack_mode) return false;

		switch ($formData.attack_mode) {
			case 'dictionary':
				return (
					$formData.wordlists &&
					$formData.wordlists.length > 0 &&
					$formData.wordlists.every((w: string) => w.trim())
				);
			case 'mask':
				return (
					$formData.mask_patterns &&
					$formData.mask_patterns.length > 0 &&
					$formData.mask_patterns.every((p: string) => p.trim())
				);
			case 'brute_force':
				return $formData.character_sets && $formData.character_sets.length > 0;
			default:
				return true;
		}
	});
</script>

<div class="space-y-6">
	<div class="text-center">
		<h3 class="text-lg font-semibold">Review Configuration</h3>
		<p class="text-muted-foreground text-sm">Review your attack settings before creating</p>
	</div>

	<!-- Status indicator -->
	<div class="flex items-center justify-center gap-2">
		{#if isComplete()}
			<CheckCircle class="h-5 w-5 text-green-500" />
			<span class="text-sm font-medium text-green-700">Configuration Complete</span>
		{:else}
			<AlertCircle class="h-5 w-5 text-amber-500" />
			<span class="text-sm font-medium text-amber-700">Configuration Incomplete</span>
		{/if}
	</div>

	<!-- Basic Settings -->
	<Card>
		<CardHeader>
			<CardTitle>Basic Settings</CardTitle>
		</CardHeader>
		<CardContent class="space-y-4">
			<div class="grid grid-cols-2 gap-4">
				<div>
					<div class="text-muted-foreground text-sm font-medium">Attack Name</div>
					<p class="text-sm" data-testid="review-attack-name">
						{$formData.name || 'Not specified'}
					</p>
				</div>
				<div>
					<div class="text-muted-foreground text-sm font-medium">Attack Mode</div>
					<p class="text-sm" data-testid="review-attack-mode">
						{$formData.attack_mode
							? getAttackModeDisplay($formData.attack_mode)
							: 'Not selected'}
					</p>
				</div>
			</div>
			{#if $formData.comment?.trim()}
				<div>
					<div class="text-muted-foreground text-sm font-medium">Comment</div>
					<p class="text-sm" data-testid="review-comment">{$formData.comment}</p>
				</div>
			{/if}
		</CardContent>
	</Card>

	<!-- Attack Configuration -->
	<Card>
		<CardHeader>
			<CardTitle>Attack Configuration</CardTitle>
		</CardHeader>
		<CardContent class="space-y-4">
			{#if $formData.attack_mode === 'dictionary'}
				{#if $formData.min_length || $formData.max_length}
					<div class="grid grid-cols-2 gap-4">
						{#if $formData.min_length}
							<div>
								<div class="text-muted-foreground text-sm font-medium">
									Minimum Length
								</div>
								<p class="text-sm" data-testid="review-min-length">
									{$formData.min_length}
								</p>
							</div>
						{/if}
						{#if $formData.max_length}
							<div>
								<div class="text-muted-foreground text-sm font-medium">
									Maximum Length
								</div>
								<p class="text-sm" data-testid="review-max-length">
									{$formData.max_length}
								</p>
							</div>
						{/if}
					</div>
				{/if}

				{#if $formData.wordlist_source}
					<div>
						<div class="text-muted-foreground text-sm font-medium">Wordlist Source</div>
						<Badge variant="secondary" data-testid="review-wordlist-source">
							{$formData.wordlist_source === 'existing'
								? 'Existing Wordlist'
								: 'Previous Passwords'}
						</Badge>
					</div>
				{/if}

				{#if $formData.wordlist_inline && $formData.wordlist_inline.length > 0}
					<div>
						<div class="text-muted-foreground text-sm font-medium">Inline Words</div>
						<div class="mt-1 flex flex-wrap gap-1" data-testid="review-inline-words">
							{#each $formData.wordlist_inline.slice(0, 10) as word, index (index)}
								<Badge variant="outline" class="text-xs">{word}</Badge>
							{/each}
							{#if $formData.wordlist_inline.length > 10}
								<Badge variant="secondary" class="text-xs">
									+{$formData.wordlist_inline.length - 10} more
								</Badge>
							{/if}
						</div>
					</div>
				{/if}
			{:else if $formData.attack_mode === 'mask'}
				{#if $formData.mask_language}
					<div>
						<div class="text-muted-foreground text-sm font-medium">Language</div>
						<Badge variant="secondary" data-testid="review-mask-language">
							{$formData.mask_language}
						</Badge>
					</div>
				{/if}

				{#if $formData.mask_patterns && $formData.mask_patterns.length > 0}
					<div>
						<div class="text-muted-foreground text-sm font-medium">Mask Patterns</div>
						<div class="mt-1 space-y-1" data-testid="review-mask-patterns">
							{#each $formData.mask_patterns as pattern, index (index)}
								<code class="bg-muted block rounded px-2 py-1 text-xs"
									>{pattern}</code
								>
							{/each}
						</div>
					</div>
				{/if}

				{#if $formData.custom_charsets && $formData.custom_charsets.length > 0}
					<div>
						<div class="text-muted-foreground text-sm font-medium">
							Custom Character Sets
						</div>
						<div class="mt-1 space-y-1" data-testid="review-custom-charsets">
							{#each $formData.custom_charsets as charset, index (index)}
								<code class="bg-muted block rounded px-2 py-1 text-xs"
									>{charset}</code
								>
							{/each}
						</div>
					</div>
				{/if}
			{:else if $formData.attack_mode === 'brute_force'}
				{#if $formData.increment_minimum || $formData.increment_maximum}
					<div class="grid grid-cols-2 gap-4">
						{#if $formData.increment_minimum}
							<div>
								<div class="text-muted-foreground text-sm font-medium">
									Minimum Length
								</div>
								<p class="text-sm" data-testid="review-increment-min">
									{$formData.increment_minimum}
								</p>
							</div>
						{/if}
						{#if $formData.increment_maximum}
							<div>
								<div class="text-muted-foreground text-sm font-medium">
									Maximum Length
								</div>
								<p class="text-sm" data-testid="review-increment-max">
									{$formData.increment_maximum}
								</p>
							</div>
						{/if}
					</div>
				{/if}

				{#if $formData.character_sets && $formData.character_sets.length > 0}
					<div>
						<div class="text-muted-foreground text-sm font-medium">Character Sets</div>
						<div class="mt-1 flex flex-wrap gap-1" data-testid="review-character-sets">
							{#each $formData.character_sets as charset, index (index)}
								<Badge variant="outline">{getCharsetDisplay(charset)}</Badge>
							{/each}
						</div>
					</div>
				{/if}
			{/if}
		</CardContent>
	</Card>

	<!-- Resources -->
	{#if $formData.attack_mode === 'dictionary'}
		<Card>
			<CardHeader>
				<CardTitle>Resources</CardTitle>
			</CardHeader>
			<CardContent class="space-y-4">
				{#if $formData.wordlists && $formData.wordlists.length > 0}
					<div>
						<div class="text-muted-foreground text-sm font-medium">Wordlists</div>
						<div class="mt-1 space-y-2" data-testid="review-wordlists">
							{#each $formData.wordlists as wordlistId, index (index)}
								{@const details = getWordlistDetails(wordlistId)}
								{#if details}
									<div
										class="bg-muted flex items-center justify-between rounded p-2"
									>
										<span class="text-sm">{details.name}</span>
										{#if details.line_count}
											<Badge variant="secondary" class="text-xs">
												{details.line_count.toLocaleString()} lines
											</Badge>
										{/if}
									</div>
								{/if}
							{/each}
						</div>
					</div>
				{/if}

				{#if $formData.rulelists && $formData.rulelists.length > 0}
					<div>
						<div class="text-muted-foreground text-sm font-medium">Rule Lists</div>
						<div class="mt-1 space-y-2" data-testid="review-rulelists">
							{#each $formData.rulelists as rulelistId, index (index)}
								{@const details = getRulelistDetails(rulelistId)}
								{#if details}
									<div
										class="bg-muted flex items-center justify-between rounded p-2"
									>
										<span class="text-sm">{details.name}</span>
										{#if details.rule_count}
											<Badge variant="secondary" class="text-xs">
												{details.rule_count.toLocaleString()} rules
											</Badge>
										{/if}
									</div>
								{/if}
							{/each}
						</div>
					</div>
				{/if}

				{#if (!$formData.wordlists || $formData.wordlists.length === 0) && (!$formData.rulelists || $formData.rulelists.length === 0)}
					<div class="text-muted-foreground py-4 text-center">
						<p class="text-sm">No resources selected</p>
					</div>
				{/if}
			</CardContent>
		</Card>
	{/if}

	{#if !isComplete}
		<Card class="border-amber-200 bg-amber-50">
			<CardContent class="pt-6">
				<div class="flex items-start gap-3">
					<AlertCircle class="mt-0.5 h-5 w-5 text-amber-500" />
					<div>
						<h4 class="text-sm font-medium text-amber-800">Configuration Incomplete</h4>
						<p class="mt-1 text-sm text-amber-700">
							Please complete all required fields before creating the attack.
						</p>
					</div>
				</div>
			</CardContent>
		</Card>
	{/if}
</div>
