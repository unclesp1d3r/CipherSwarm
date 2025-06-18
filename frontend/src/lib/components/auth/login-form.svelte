<script lang="ts">
	import { Field, Control, Label, FieldErrors } from 'formsnap';
	import { superForm } from 'sveltekit-superforms';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import { loginSchema } from '$lib/schemas/auth';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Input } from '$lib/components/ui/input/index.js';
	import { Checkbox } from '$lib/components/ui/checkbox/index.js';
	import {
		Card,
		CardContent,
		CardDescription,
		CardHeader,
		CardTitle
	} from '$lib/components/ui/card/index.js';
	import { Alert, AlertDescription } from '$lib/components/ui/alert/index.js';
	import { Loader2 } from 'lucide-svelte';

	// Props
	let {
		data
	}: {
		data: any;
	} = $props();

	// Form handling with Superforms
	const form = superForm(data.form, {
		validators: zodClient(loginSchema)
	});

	const { form: formData, errors, enhance, submitting, message } = form;

	// Get form state
	let loading = $derived($submitting);
	let error = $derived($message);
</script>

<Card class="w-full max-w-sm">
	<CardHeader>
		<CardTitle class="text-2xl">Login</CardTitle>
		<CardDescription>Enter your email below to login to your account</CardDescription>
	</CardHeader>
	<CardContent>
		<form method="POST" use:enhance class="grid gap-4">
			<!-- Error Display -->
			{#if error}
				<Alert variant="destructive">
					<AlertDescription>{error}</AlertDescription>
				</Alert>
			{/if}

			<!-- Email Field -->
			<Field {form} name="email">
				<Control>
					{#snippet children({ props })}
						<Label>Email</Label>
						<Input
							{...props}
							type="email"
							placeholder="m@example.com"
							bind:value={$formData.email}
							disabled={loading}
							required
						/>
					{/snippet}
				</Control>
				<FieldErrors />
			</Field>

			<!-- Password Field -->
			<Field {form} name="password">
				<Control>
					{#snippet children({ props })}
						<Label>Password</Label>
						<Input
							{...props}
							type="password"
							bind:value={$formData.password}
							disabled={loading}
							required
						/>
					{/snippet}
				</Control>
				<FieldErrors />
			</Field>

			<!-- Remember Me -->
			<div class="flex items-center space-x-2">
				<Field {form} name="remember">
					<Control>
						{#snippet children({ props })}
							<Checkbox
								{...props}
								bind:checked={$formData.remember}
								disabled={loading}
							/>
							<Label class="text-sm font-normal">Remember me</Label>
						{/snippet}
					</Control>
				</Field>
			</div>

			<!-- Submit Button -->
			<Button type="submit" class="w-full" disabled={loading}>
				{#if loading}
					<Loader2 class="mr-2 h-4 w-4 animate-spin" />
					Signing in...
				{:else}
					Sign In
				{/if}
			</Button>
		</form>
	</CardContent>
</Card>
