<script lang="ts">
	import { superForm, type SuperValidated } from 'sveltekit-superforms';
	import { zodClient } from 'sveltekit-superforms/adapters';
	import { loginSchema } from '$lib/schemas/auth';
	import { Button } from '$lib/components/ui/button/index.js';
	import { Input } from '$lib/components/ui/input/index.js';
	import { Label } from '$lib/components/ui/label/index.js';
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
	import type { z } from 'zod';

	type LoginData = z.infer<typeof loginSchema>;

	// Props
	let {
		data
	}: {
		data: { form: SuperValidated<LoginData> };
	} = $props();

	// Form handling with Superforms
	const { form, errors, enhance, submitting, message } = superForm(data.form, {
		validators: zodClient(loginSchema),
		dataType: 'json'
	});

	// Get form state
	let loading = $derived($submitting);
	let errorMessage = $derived($message && $message.type === 'error' ? $message.text : null);
</script>

<Card class="w-full max-w-sm">
	<CardHeader>
		<CardTitle class="text-2xl">Login</CardTitle>
		<CardDescription>Enter your email below to login to your account</CardDescription>
	</CardHeader>
	<CardContent>
		<form method="POST" use:enhance class="grid gap-4">
			<!-- Error Display -->
			{#if errorMessage}
				<Alert variant="destructive">
					<AlertDescription>{errorMessage}</AlertDescription>
				</Alert>
			{/if}

			<!-- Email Field -->
			<div class="grid gap-2">
				<Label for="email">Email</Label>
				<Input
					id="email"
					name="email"
					type="email"
					placeholder="m@example.com"
					bind:value={$form.email}
					disabled={loading}
					required
				/>
				{#if $errors.email}
					<p class="text-destructive text-sm">{$errors.email}</p>
				{/if}
			</div>

			<!-- Password Field -->
			<div class="grid gap-2">
				<Label for="password">Password</Label>
				<Input
					id="password"
					name="password"
					type="password"
					bind:value={$form.password}
					disabled={loading}
					required
				/>
				{#if $errors.password}
					<p class="text-destructive text-sm">{$errors.password}</p>
				{/if}
			</div>

			<!-- Remember Me -->
			<div class="flex items-center space-x-2">
				<Checkbox
					id="remember"
					name="remember"
					bind:checked={$form.remember}
					disabled={loading}
				/>
				<Label for="remember" class="text-sm font-normal">Remember me</Label>
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
