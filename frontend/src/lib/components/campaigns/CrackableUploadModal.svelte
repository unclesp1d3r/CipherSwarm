<script lang="ts">
	import { createEventDispatcher } from 'svelte';
	import * as Dialog from '$lib/components/ui/dialog';
	import { Button } from '$lib/components/ui/button';
	import { Input } from '$lib/components/ui/input';
	import { Label } from '$lib/components/ui/label';
	import { Textarea } from '$lib/components/ui/textarea';
	import { Alert, AlertDescription } from '$lib/components/ui/alert';
	import { Badge } from '$lib/components/ui/badge';
	import { Progress } from '$lib/components/ui/progress';
	import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
	import { Separator } from '$lib/components/ui/separator';
	import { Select, SelectContent, SelectItem, SelectTrigger } from '$lib/components/ui/select';
	import {
		Upload,
		FileText,
		Hash,
		AlertTriangle,
		CheckCircle,
		ChevronDown
	} from '@lucide/svelte';
	import axios from 'axios';

	interface HashGuessCandidate {
		hash_type: number;
		name: string;
		confidence: number;
	}

	interface HashGuessResults {
		candidates: HashGuessCandidate[];
	}

	interface HashTypeDropdownItem {
		mode: number;
		name: string;
		category: string;
		confidence?: number;
	}

	interface UploadResponse {
		resource_id: number;
		presigned_url?: string;
		resource: {
			file_name: string;
		};
	}

	let {
		open = $bindable(false),
		projectId = null
	}: {
		open?: boolean;
		projectId?: number | null;
	} = $props();

	const dispatch = createEventDispatcher<{
		close: void;
		success: { uploadId: number };
	}>();

	// Form state
	let uploadMode: 'text' | 'file' = $state('text');
	let textContent = $state('');
	let fileName = $state('');
	let fileLabel = $state('');
	let selectedFile: File | null = $state(null);

	// Validation state
	let hashGuessResults: HashGuessResults | null = $state(null);
	let isValidating = $state(false);
	let validationError = $state('');
	let hasValidHashes = $state(false);

	// Hash type selection state
	let availableHashTypes: HashTypeDropdownItem[] = $state([]);
	let selectedHashTypeId: string = $state('');
	let isLoadingHashTypes = $state(false);
	let showHashTypeOverride = $state(false);

	// Upload state
	let isUploading = $state(false);
	let uploadError = $state('');

	function handleClose() {
		open = false;
		resetForm();
		dispatch('close');
	}

	function resetForm() {
		uploadMode = 'text';
		textContent = '';
		fileName = '';
		fileLabel = '';
		selectedFile = null;
		hashGuessResults = null;
		isValidating = false;
		validationError = '';
		hasValidHashes = false;
		availableHashTypes = [];
		selectedHashTypeId = '';
		isLoadingHashTypes = false;
		showHashTypeOverride = false;
		isUploading = false;
		uploadError = '';
	}

	function handleFileSelect(event: Event) {
		const target = event.target as HTMLInputElement;
		const file = target.files?.[0];
		if (file) {
			selectedFile = file;
			fileName = file.name;
			// Clear text content when file is selected
			textContent = '';
		}
	}

	async function loadHashTypes() {
		if (!hashGuessResults?.candidates?.length) return;

		isLoadingHashTypes = true;
		try {
			const response = await axios.get<HashTypeDropdownItem[]>(
				'/api/v1/web/modals/hash_types'
			);
			const allHashTypes = response.data;

			// Create a map of detected hash types with their confidence scores
			const detectedHashTypes = new Map(
				hashGuessResults.candidates.map((candidate) => [
					candidate.hash_type,
					candidate.confidence
				])
			);

			// Filter hash types to only include those detected by the guess service
			// and add confidence scores
			availableHashTypes = allHashTypes
				.filter((hashType) => detectedHashTypes.has(hashType.mode))
				.map((hashType) => ({
					...hashType,
					confidence: detectedHashTypes.get(hashType.mode)
				}))
				.sort((a, b) => {
					// Sort by confidence descending, then by mode ascending
					if (a.confidence !== b.confidence) {
						return (b.confidence || 0) - (a.confidence || 0);
					}
					return a.mode - b.mode;
				});

			// Auto-select the highest confidence hash type
			if (availableHashTypes.length > 0) {
				selectedHashTypeId = availableHashTypes[0].mode.toString();
			}
		} catch (error) {
			console.error('Failed to load hash types:', error);
		} finally {
			isLoadingHashTypes = false;
		}
	}

	async function validateHashes() {
		if (!textContent.trim()) {
			validationError = 'Please enter hash content to validate';
			return;
		}

		isValidating = true;
		validationError = '';
		hashGuessResults = null;
		hasValidHashes = false;
		showHashTypeOverride = false;
		availableHashTypes = [];
		selectedHashTypeId = '';

		try {
			const response = await axios.post<HashGuessResults>('/api/v1/web/hash_guess/', {
				hash_material: textContent
			});

			hashGuessResults = response.data;
			hasValidHashes = response.data.candidates.length > 0;

			if (!hasValidHashes) {
				validationError = 'No valid hash types detected. Please check your input format.';
			} else {
				// Load available hash types for the dropdown
				await loadHashTypes();
			}
		} catch (error) {
			console.error('Hash validation failed:', error);
			validationError = 'Failed to validate hashes. Please try again.';
			hasValidHashes = false;
		} finally {
			isValidating = false;
		}
	}

	function toggleHashTypeOverride() {
		showHashTypeOverride = !showHashTypeOverride;
	}

	function confirmHashTypeSelection() {
		showHashTypeOverride = false;
	}

	async function handleUpload() {
		if (!projectId) {
			uploadError = 'Project ID is required';
			return;
		}

		// For text mode, validate hashes first if not already validated
		if (uploadMode === 'text' && !hasValidHashes) {
			await validateHashes();
			if (!hasValidHashes) {
				return;
			}
		}

		isUploading = true;
		uploadError = '';

		try {
			const formData = new FormData();
			formData.append('project_id', projectId.toString());

			if (uploadMode === 'text') {
				formData.append('text_content', textContent);
				if (fileName) {
					formData.append('file_name', fileName);
				}
				// Include selected hash type if available
				if (selectedHashTypeId) {
					formData.append('hash_type_override', selectedHashTypeId);
				}
			} else {
				if (!selectedFile) {
					uploadError = 'Please select a file to upload';
					return;
				}
				formData.append('file_name', selectedFile.name);
			}

			if (fileLabel) {
				formData.append('file_label', fileLabel);
			}

			const response = await axios.post<UploadResponse>('/api/v1/web/uploads/', formData);

			// If it's a file upload, we need to upload to the presigned URL
			if (uploadMode === 'file' && response.data.presigned_url && selectedFile) {
				await axios.put(response.data.presigned_url, selectedFile, {
					headers: {
						'Content-Type': selectedFile.type || 'application/octet-stream'
					}
				});
			}

			dispatch('success', { uploadId: response.data.resource_id });
			handleClose();
		} catch (error) {
			console.error('Upload failed:', error);
			uploadError = 'Upload failed. Please try again.';
		} finally {
			isUploading = false;
		}
	}

	function getConfidenceColor(confidence: number): string {
		if (confidence >= 0.8) return 'bg-green-600';
		if (confidence >= 0.6) return 'bg-yellow-600';
		return 'bg-orange-600';
	}

	function formatConfidence(confidence: number): string {
		return `${Math.round(confidence * 100)}%`;
	}

	const selectedHashType = $derived(
		availableHashTypes.find((ht) => ht.mode.toString() === selectedHashTypeId)
	);
</script>

<Dialog.Root bind:open onOpenChange={handleClose}>
	<Dialog.Content class="max-h-[90vh] overflow-y-auto sm:max-w-2xl">
		<Dialog.Header>
			<Dialog.Title data-testid="modal-title">Upload Crackable Content</Dialog.Title>
			<Dialog.Description>
				Upload files or paste hash content to automatically create a campaign with detected
				hash types
			</Dialog.Description>
		</Dialog.Header>

		{#if uploadError}
			<Alert variant="destructive">
				<AlertTriangle class="h-4 w-4" />
				<AlertDescription data-testid="upload-error">{uploadError}</AlertDescription>
			</Alert>
		{/if}

		<div class="space-y-6">
			<!-- Upload Mode Selection -->
			<div class="flex gap-2">
				<Button
					variant={uploadMode === 'text' ? 'default' : 'outline'}
					onclick={() => {
						uploadMode = 'text';
						selectedFile = null;
					}}
					data-testid="text-mode-button"
				>
					<FileText class="mr-2 h-4 w-4" />
					Paste Hashes
				</Button>
				<Button
					variant={uploadMode === 'file' ? 'default' : 'outline'}
					onclick={() => {
						uploadMode = 'file';
						textContent = '';
						hashGuessResults = null;
						hasValidHashes = false;
						showHashTypeOverride = false;
						availableHashTypes = [];
						selectedHashTypeId = '';
					}}
					data-testid="file-mode-button"
				>
					<Upload class="mr-2 h-4 w-4" />
					Upload File
				</Button>
			</div>

			<!-- Text Content Mode -->
			{#if uploadMode === 'text'}
				<div class="space-y-4">
					<div class="space-y-2">
						<Label for="text-content">Hash Content</Label>
						<Textarea
							id="text-content"
							bind:value={textContent}
							placeholder="Paste your hashes here (e.g., from /etc/shadow, NTLM dumps, etc.)&#10;&#10;Examples:&#10;user:$6$salt$hash...&#10;5d41402abc4b2a76b9719d911017c592&#10;admin:aad3b435b51404eeaad3b435b51404ee:8846f7eaee8fb117ad06bdd830b7586c"
							rows={8}
							data-testid="text-content-input"
							class="font-mono text-sm"
						/>
					</div>

					<div class="flex gap-2">
						<Button
							onclick={validateHashes}
							disabled={!textContent.trim() || isValidating}
							variant="outline"
							data-testid="validate-button"
						>
							{#if isValidating}
								<div
									class="mr-2 h-4 w-4 animate-spin rounded-full border-b-2 border-current"
								></div>
								Validating...
							{:else}
								<Hash class="mr-2 h-4 w-4" />
								Validate Hashes
							{/if}
						</Button>
					</div>

					{#if validationError}
						<Alert variant="destructive">
							<AlertTriangle class="h-4 w-4" />
							<AlertDescription data-testid="validation-error"
								>{validationError}</AlertDescription
							>
						</Alert>
					{/if}

					<!-- Hash Guess Results -->
					{#if hashGuessResults}
						<Card>
							<CardHeader>
								<CardTitle class="flex items-center gap-2">
									{#if hasValidHashes}
										<CheckCircle class="h-5 w-5 text-green-600" />
										Detected Hash Types
									{:else}
										<AlertTriangle class="h-5 w-5 text-orange-600" />
										No Hash Types Detected
									{/if}
								</CardTitle>
							</CardHeader>
							<CardContent>
								{#if hashGuessResults.candidates.length > 0}
									<div class="space-y-2">
										{#each hashGuessResults.candidates.slice(0, 5) as candidate (candidate.hash_type)}
											<div
												class="flex items-center justify-between rounded border p-2"
											>
												<div>
													<span class="font-medium">{candidate.name}</span
													>
													<span class="ml-2 text-sm text-gray-500"
														>Mode {candidate.hash_type}</span
													>
												</div>
												<Badge
													class={getConfidenceColor(candidate.confidence)}
												>
													{formatConfidence(candidate.confidence)}
												</Badge>
											</div>
										{/each}
									</div>

									<!-- Hash Type Override Section -->
									{#if availableHashTypes.length > 0}
										<div class="mt-4 space-y-3">
											<Separator />
											<div class="flex items-center justify-between">
												<div>
													<h4 class="text-sm font-medium">
														Hash Type Selection
													</h4>
													<p class="text-xs text-gray-600">
														Confirm or override the detected hash type
													</p>
												</div>
												<Button
													variant="outline"
													size="sm"
													onclick={toggleHashTypeOverride}
													data-testid="override-hash-type-button"
												>
													{showHashTypeOverride
														? 'Hide Options'
														: 'Override Type'}
													<ChevronDown class="ml-1 h-3 w-3" />
												</Button>
											</div>

											{#if showHashTypeOverride}
												<div class="space-y-3">
													<div class="space-y-2">
														<Label for="hash-type-select"
															>Select Hash Type</Label
														>
														{#if isLoadingHashTypes}
															<div
																class="flex items-center gap-2 text-sm text-gray-600"
															>
																<div
																	class="h-4 w-4 animate-spin rounded-full border-b-2 border-current"
																></div>
																Loading hash types...
															</div>
														{:else}
															<Select
																type="single"
																bind:value={selectedHashTypeId}
															>
																<SelectTrigger
																	id="hash-type-select"
																	data-testid="hash-type-select"
																>
																	<span>
																		{selectedHashType
																			? `${selectedHashType.name} (Mode ${selectedHashType.mode})`
																			: 'Select a hash type'}
																	</span>
																</SelectTrigger>
																<SelectContent>
																	{#each availableHashTypes as hashType (hashType.mode)}
																		<SelectItem
																			value={hashType.mode.toString()}
																			data-testid="hash-type-option-{hashType.mode}"
																		>
																			<div
																				class="flex w-full items-center justify-between"
																			>
																				<div
																					class="flex flex-col"
																				>
																					<span
																						class="font-medium"
																						>{hashType.name}</span
																					>
																					<span
																						class="text-xs text-gray-500"
																					>
																						Mode {hashType.mode}
																						• {hashType.category}
																					</span>
																				</div>
																				{#if hashType.confidence}
																					<Badge
																						class={getConfidenceColor(
																							hashType.confidence
																						)}
																						variant="secondary"
																					>
																						{formatConfidence(
																							hashType.confidence
																						)}
																					</Badge>
																				{/if}
																			</div>
																		</SelectItem>
																	{/each}
																</SelectContent>
															</Select>
														{/if}
													</div>

													{#if selectedHashType}
														<div class="rounded border bg-gray-50 p-3">
															<div
																class="flex items-center justify-between"
															>
																<div>
																	<p class="text-sm font-medium">
																		{selectedHashType.name}
																	</p>
																	<p
																		class="text-xs text-gray-600"
																	>
																		Mode {selectedHashType.mode}
																		• {selectedHashType.category}
																	</p>
																</div>
																{#if selectedHashType.confidence}
																	<Badge
																		class={getConfidenceColor(
																			selectedHashType.confidence
																		)}
																	>
																		{formatConfidence(
																			selectedHashType.confidence
																		)} confidence
																	</Badge>
																{/if}
															</div>
														</div>
													{/if}

													<div class="flex gap-2">
														<Button
															variant="outline"
															size="sm"
															onclick={confirmHashTypeSelection}
															data-testid="confirm-hash-type-button"
														>
															Confirm Selection
														</Button>
													</div>
												</div>
											{:else if selectedHashType}
												<div class="rounded border bg-green-50 p-3">
													<div class="flex items-center justify-between">
														<div>
															<p class="text-sm font-medium">
																Selected: {selectedHashType.name}
															</p>
															<p class="text-xs text-gray-600">
																Mode {selectedHashType.mode} • {selectedHashType.category}
															</p>
														</div>
														{#if selectedHashType.confidence}
															<Badge
																class={getConfidenceColor(
																	selectedHashType.confidence
																)}
															>
																{formatConfidence(
																	selectedHashType.confidence
																)} confidence
															</Badge>
														{/if}
													</div>
												</div>
											{/if}
										</div>
									{/if}
								{:else}
									<p class="text-sm text-gray-600">
										No valid hash types detected. Please check your input format
										and try again.
									</p>
								{/if}
							</CardContent>
						</Card>
					{/if}
				</div>
			{/if}

			<!-- File Upload Mode -->
			{#if uploadMode === 'file'}
				<div class="space-y-4">
					<div class="space-y-2">
						<Label for="file-input">Select File</Label>
						<Input
							id="file-input"
							type="file"
							onchange={handleFileSelect}
							accept=".shadow,.pdf,.zip,.7z,.docx"
							data-testid="file-input"
						/>
						<p class="text-sm text-gray-600">
							Supported formats: .shadow, .pdf, .zip, .7z, .docx
						</p>
					</div>

					{#if selectedFile}
						<Alert>
							<FileText class="h-4 w-4" />
							<AlertDescription>
								Selected: {selectedFile.name} ({Math.round(
									selectedFile.size / 1024
								)} KB)
							</AlertDescription>
						</Alert>
					{/if}
				</div>
			{/if}

			<!-- Common Fields -->
			<Separator />

			<div class="space-y-4">
				<div class="space-y-2">
					<Label for="file-label">Label (Optional)</Label>
					<Input
						id="file-label"
						bind:value={fileLabel}
						placeholder="Descriptive label for this upload"
						data-testid="file-label-input"
					/>
				</div>

				{#if uploadMode === 'text'}
					<div class="space-y-2">
						<Label for="file-name">File Name (Optional)</Label>
						<Input
							id="file-name"
							bind:value={fileName}
							placeholder="custom_hashes.txt"
							data-testid="file-name-input"
						/>
					</div>
				{/if}
			</div>
		</div>

		<Dialog.Footer class="flex justify-between">
			<Button variant="outline" onclick={handleClose} data-testid="cancel-button">
				Cancel
			</Button>
			<Button
				onclick={handleUpload}
				disabled={isUploading ||
					(uploadMode === 'text' && (!textContent.trim() || !hasValidHashes)) ||
					(uploadMode === 'file' && !selectedFile)}
				data-testid="upload-button"
			>
				{#if isUploading}
					<div
						class="mr-2 h-4 w-4 animate-spin rounded-full border-b-2 border-current"
					></div>
					Uploading...
				{:else}
					<Upload class="mr-2 h-4 w-4" />
					Create Campaign
				{/if}
			</Button>
		</Dialog.Footer>
	</Dialog.Content>
</Dialog.Root>
