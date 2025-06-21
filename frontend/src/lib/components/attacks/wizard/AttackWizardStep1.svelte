<script lang="ts">
    import { type SuperForm } from 'sveltekit-superforms';
    import { type AttackFormData } from '$lib/schemas/attack.js';
    import {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    } from '$lib/components/ui/card/index.js';
    import { Label } from '$lib/components/ui/label/index.js';
    import { Input } from '$lib/components/ui/input/index.js';
    import { Textarea } from '$lib/components/ui/textarea/index.js';
    import { Button } from '$lib/components/ui/button/index.js';

    interface Props {
        form: SuperForm<AttackFormData>;
        errors: unknown;
        resources: unknown;
    }

    let { form, errors, resources }: Props = $props();
    const { form: formData } = form;
</script>

<Card>
    <CardHeader>
        <CardTitle>Basic Settings</CardTitle>
        <CardDescription>Configure the basic attack parameters</CardDescription>
    </CardHeader>
    <CardContent class="space-y-6">
        <div class="space-y-2">
            <Label for="name">Attack Name *</Label>
            <Input
                id="name"
                name="name"
                bind:value={$formData.name}
                placeholder="Enter attack name"
                required />
        </div>

        <div class="space-y-2">
            <Label for="comment">Comment (Optional)</Label>
            <Textarea
                id="comment"
                name="comment"
                bind:value={$formData.comment}
                placeholder="Enter optional comment"
                rows={3} />
        </div>

        <div class="space-y-4">
            <Label>Select Attack Type *</Label>
            <div class="grid grid-cols-1 gap-4 md:grid-cols-3">
                {#each [{ value: 'dictionary', label: 'Dictionary Attack', description: 'Use wordlists to crack passwords' }, { value: 'mask', label: 'Mask Attack', description: 'Use patterns to generate candidates' }, { value: 'brute_force', label: 'Brute Force', description: 'Try all possible combinations' }] as attackType (attackType.value)}
                    <Card
                        class="hover:bg-muted cursor-pointer transition-colors {$formData.attack_mode ===
                        attackType.value
                            ? 'ring-primary ring-2'
                            : ''}"
                        onclick={() =>
                            ($formData.attack_mode = attackType.value as
                                | 'dictionary'
                                | 'mask'
                                | 'brute_force')}>
                        <CardContent class="p-4">
                            <div class="space-y-2">
                                <h4 class="font-medium">{attackType.label}</h4>
                                <p class="text-muted-foreground text-sm">
                                    {attackType.description}
                                </p>
                            </div>
                        </CardContent>
                    </Card>
                {/each}
            </div>
        </div>
    </CardContent>
</Card>
