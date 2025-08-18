<script lang="ts">
    import { goto } from '$app/navigation';
    import AttackWizardStep1 from '$lib/components/attacks/wizard/AttackWizardStep1.svelte';
    import AttackWizardStep2 from '$lib/components/attacks/wizard/AttackWizardStep2.svelte';
    import AttackWizardStep3 from '$lib/components/attacks/wizard/AttackWizardStep3.svelte';
    import AttackWizardStep4 from '$lib/components/attacks/wizard/AttackWizardStep4.svelte';
    import { Alert, AlertDescription } from '$lib/components/ui/alert';
    import { Button } from '$lib/components/ui/button';
    import { Dialog, DialogContent, DialogHeader, DialogTitle } from '$lib/components/ui/dialog';
    import { attackSchema } from '$lib/schemas/attack';
    import { ChevronLeft, ChevronRight, X } from '@lucide/svelte/icons';
    import { superForm } from 'sveltekit-superforms';
    import { zod4Client } from 'sveltekit-superforms/adapters';

    // SSR data from +page.server.ts
    let { data } = $props();

    // Wizard state using Svelte 5 runes
    let currentStep = $state(1);
    let isModalOpen = $state(true);

    // Superforms setup
    const superFormResult = superForm(data.form, {
        validators: zod4Client(attackSchema),
        resetForm: false,
        invalidateAll: false,
    });
    const { form, errors, enhance, submitting, message } = superFormResult;

    // Wizard configuration
    const steps = [
        { id: 1, title: 'Basic Settings', description: 'Attack name and mode' },
        { id: 2, title: 'Attack Configuration', description: 'Configure attack parameters' },
        { id: 3, title: 'Resources', description: 'Select wordlists and rules' },
        { id: 4, title: 'Review', description: 'Review and create attack' },
    ];

    // Navigation functions
    function nextStep() {
        if (currentStep < steps.length) {
            currentStep++;
        }
    }

    function prevStep() {
        if (currentStep > 1) {
            currentStep--;
        }
    }

    function canProceedToNext(): boolean {
        switch (currentStep) {
            case 1:
                // Basic validation for step 1
                return $form.name.trim().length > 0 && $form.attack_mode !== undefined;
            case 2:
                // Attack mode specific validation
                if ($form.attack_mode === 'dictionary') {
                    return (
                        $form.min_length > 0 &&
                        $form.max_length > 0 &&
                        $form.max_length >= $form.min_length
                    );
                } else if ($form.attack_mode === 'brute_force') {
                    return (
                        $form.increment_minimum > 0 &&
                        $form.increment_maximum > 0 &&
                        $form.increment_maximum >= $form.increment_minimum
                    );
                }
                return true;
            case 3:
                // Resource validation if needed
                return true;
            default:
                return true;
        }
    }

    function handleClose() {
        isModalOpen = false;
        goto('/attacks');
    }

    function handleKeydown(event: KeyboardEvent) {
        if (event.key === 'Escape') {
            handleClose();
        }
    }

    // Step transition animation classes
    function getStepClasses(stepId: number): string {
        if (stepId === currentStep) {
            return 'translate-x-0 opacity-100';
        } else if (stepId < currentStep) {
            return '-translate-x-full opacity-0';
        } else {
            return 'translate-x-full opacity-0';
        }
    }
</script>

<svelte:window on:keydown={handleKeydown} />

<Dialog bind:open={isModalOpen} onOpenChange={handleClose}>
    <DialogContent class="max-h-[90vh] max-w-4xl overflow-hidden">
        <DialogHeader>
            <div class="flex items-center justify-between">
                <DialogTitle>Create New Attack</DialogTitle>
                <Button variant="ghost" size="sm" onclick={handleClose}>
                    <X class="h-4 w-4" />
                </Button>
            </div>
        </DialogHeader>

        <!-- Progress indicator -->
        <div class="mb-6 flex items-center justify-between">
            {#each steps as step, index (step.id)}
                <div class="flex items-center {index < steps.length - 1 ? 'flex-1' : ''}">
                    <div class="flex items-center">
                        <div
                            class="flex h-8 w-8 items-center justify-center rounded-full text-sm font-medium transition-colors
								{step.id <= currentStep ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground'}">
                            {step.id}
                        </div>
                        <div class="ml-3 hidden sm:block">
                            <div
                                class="text-sm font-medium {step.id <= currentStep
                                    ? 'text-foreground'
                                    : 'text-muted-foreground'}">
                                {step.title}
                            </div>
                            <div class="text-muted-foreground text-xs">
                                {step.description}
                            </div>
                        </div>
                    </div>
                    {#if index < steps.length - 1}
                        <div class="bg-border mx-4 h-px flex-1"></div>
                    {/if}
                </div>
            {/each}
        </div>

        <!-- Form content -->
        <form method="POST" use:enhance class="space-y-6">
            <div class="relative min-h-[400px] overflow-hidden">
                <!-- Step 1: Basic Settings -->
                <div
                    class="absolute inset-0 transition-transform duration-300 ease-in-out {getStepClasses(
                        1
                    )}">
                    {#if currentStep === 1}
                        <AttackWizardStep1
                            form={superFormResult}
                            {errors}
                            resources={data.resources} />
                    {/if}
                </div>

                <!-- Step 2: Attack Configuration -->
                <div
                    class="absolute inset-0 transition-transform duration-300 ease-in-out {getStepClasses(
                        2
                    )}">
                    {#if currentStep === 2}
                        <AttackWizardStep2
                            form={superFormResult}
                            {errors}
                            resources={data.resources} />
                    {/if}
                </div>

                <!-- Step 3: Resources -->
                <div
                    class="absolute inset-0 transition-transform duration-300 ease-in-out {getStepClasses(
                        3
                    )}">
                    {#if currentStep === 3}
                        <AttackWizardStep3
                            form={superFormResult}
                            wordlists={data.resources.wordlists}
                            rulelists={data.resources.rulelists} />
                    {/if}
                </div>

                <!-- Step 4: Review -->
                <div
                    class="absolute inset-0 transition-transform duration-300 ease-in-out {getStepClasses(
                        4
                    )}">
                    {#if currentStep === 4}
                        <AttackWizardStep4
                            form={superFormResult}
                            wordlists={data.resources.wordlists}
                            rulelists={data.resources.rulelists} />
                    {/if}
                </div>
            </div>

            <!-- Error display -->
            {#if $message}
                <Alert variant="destructive">
                    <AlertDescription>{$message}</AlertDescription>
                </Alert>
            {/if}

            <!-- Navigation buttons -->
            <div class="flex justify-between border-t pt-6">
                <Button
                    type="button"
                    variant="outline"
                    onclick={prevStep}
                    disabled={currentStep === 1}>
                    <ChevronLeft class="mr-2 h-4 w-4" />
                    Previous
                </Button>

                <div class="flex gap-2">
                    <Button type="button" variant="ghost" onclick={handleClose}>Cancel</Button>

                    {#if currentStep < steps.length}
                        <Button type="button" onclick={nextStep} disabled={!canProceedToNext()}>
                            Next
                            <ChevronRight class="ml-2 h-4 w-4" />
                        </Button>
                    {:else}
                        <Button type="submit" disabled={$submitting}>
                            {$submitting ? 'Creating...' : 'Create Attack'}
                        </Button>
                    {/if}
                </div>
            </div>
        </form>
    </DialogContent>
</Dialog>
