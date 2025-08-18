<script lang="ts">
    import { Button } from '$lib/components/ui/button/index.js';
    import {
        Card,
        CardContent,
        CardDescription,
        CardHeader,
        CardTitle,
    } from '$lib/components/ui/card/index.js';
    import { Checkbox } from '$lib/components/ui/checkbox/index.js';
    import { Input } from '$lib/components/ui/input/index.js';
    import { Label } from '$lib/components/ui/label/index.js';
    import { type AttackFormData } from '$lib/schemas/attack.js';
    import { Plus, Trash2 } from '@lucide/svelte';
    import { type SuperForm } from 'sveltekit-superforms';

    interface Props {
        form: SuperForm<AttackFormData>;
        errors: unknown;
        resources: unknown;
    }

    let { form, errors, resources }: Props = $props();
    const { form: formData } = form;

    function addMaskLine() {
        if ($formData.attack_mode === 'mask' && $formData.masks_inline) {
            $formData.masks_inline = [...$formData.masks_inline, ''];
        }
    }

    function removeMaskLine(index: number) {
        if ($formData.attack_mode === 'mask' && $formData.masks_inline) {
            $formData.masks_inline = $formData.masks_inline.filter(
                (_: string, i: number) => i !== index
            );
        }
    }

    function addWordInline() {
        if ($formData.attack_mode === 'dictionary' && $formData.wordlist_inline) {
            $formData.wordlist_inline = [...$formData.wordlist_inline, ''];
        }
    }

    function removeWordInline(index: number) {
        if ($formData.attack_mode === 'dictionary' && $formData.wordlist_inline) {
            $formData.wordlist_inline = $formData.wordlist_inline.filter(
                (_: string, i: number) => i !== index
            );
        }
    }
</script>

<Card>
    <CardHeader>
        <CardTitle>Attack Configuration</CardTitle>
        <CardDescription
            >Configure the specific parameters for your {$formData.attack_mode} attack</CardDescription>
    </CardHeader>
    <CardContent class="space-y-6">
        {#if $formData.attack_mode === 'dictionary'}
            <div class="space-y-4">
                <div class="grid grid-cols-2 gap-4">
                    <div class="space-y-2">
                        <Label for="min_length">Minimum Length</Label>
                        <Input
                            id="min_length"
                            type="number"
                            bind:value={$formData.min_length}
                            placeholder="1" />
                    </div>
                    <div class="space-y-2">
                        <Label for="max_length">Maximum Length</Label>
                        <Input
                            id="max_length"
                            type="number"
                            bind:value={$formData.max_length}
                            placeholder="16" />
                    </div>
                </div>

                <div class="space-y-2">
                    <Label>Wordlist Source</Label>
                    <div class="flex gap-4">
                        <label class="flex items-center space-x-2">
                            <input
                                type="radio"
                                bind:group={$formData.wordlist_source}
                                value="existing" />
                            <span>Existing Wordlists</span>
                        </label>
                        <label class="flex items-center space-x-2">
                            <input
                                type="radio"
                                bind:group={$formData.wordlist_source}
                                value="previous_passwords" />
                            <span>Previous Passwords</span>
                        </label>
                    </div>
                </div>

                {#if $formData.wordlist_source === 'previous_passwords'}
                    <div class="space-y-4">
                        <div class="space-y-2">
                            <Label>Inline Words</Label>
                            {#each $formData.wordlist_inline || [] as word, index (index)}
                                <div class="flex gap-2">
                                    <Input
                                        bind:value={$formData.wordlist_inline[index]}
                                        placeholder="Enter word" />
                                    <Button
                                        type="button"
                                        variant="outline"
                                        size="sm"
                                        onclick={() => removeWordInline(index)}>
                                        <Trash2 class="h-4 w-4" />
                                    </Button>
                                </div>
                            {/each}
                            <Button type="button" variant="outline" onclick={addWordInline}>
                                <Plus class="mr-2 h-4 w-4" />
                                Add Word
                            </Button>
                        </div>
                    </div>
                {/if}
            </div>
        {:else if $formData.attack_mode === 'mask'}
            <div class="space-y-4">
                <div class="space-y-2">
                    <Label for="mask">Primary Mask Pattern</Label>
                    <Input id="mask" bind:value={$formData.mask} placeholder="?l?l?l?l?d?d?d?d" />
                </div>

                <div class="space-y-2">
                    <Label>Additional Mask Patterns</Label>
                    {#each $formData.masks_inline || [] as mask, index (index)}
                        <div class="flex gap-2">
                            <Input
                                bind:value={$formData.masks_inline[index]}
                                placeholder="Enter mask pattern" />
                            <Button
                                type="button"
                                variant="outline"
                                size="sm"
                                onclick={() => removeMaskLine(index)}>
                                <Trash2 class="h-4 w-4" />
                            </Button>
                        </div>
                    {/each}
                    <Button type="button" variant="outline" onclick={addMaskLine}>
                        <Plus class="mr-2 h-4 w-4" />
                        Add Mask
                    </Button>
                </div>

                <div class="space-y-4">
                    <Label>Custom Character Sets</Label>
                    <div class="grid grid-cols-2 gap-4">
                        <div class="space-y-2">
                            <Label for="custom_charset_1">Custom Charset 1</Label>
                            <Input
                                id="custom_charset_1"
                                bind:value={$formData.custom_charset_1}
                                placeholder="abcdefghijklmnopqrstuvwxyz" />
                        </div>
                        <div class="space-y-2">
                            <Label for="custom_charset_2">Custom Charset 2</Label>
                            <Input
                                id="custom_charset_2"
                                bind:value={$formData.custom_charset_2}
                                placeholder="ABCDEFGHIJKLMNOPQRSTUVWXYZ" />
                        </div>
                        <div class="space-y-2">
                            <Label for="custom_charset_3">Custom Charset 3</Label>
                            <Input
                                id="custom_charset_3"
                                bind:value={$formData.custom_charset_3}
                                placeholder="0123456789" />
                        </div>
                        <div class="space-y-2">
                            <Label for="custom_charset_4">Custom Charset 4</Label>
                            <Input
                                id="custom_charset_4"
                                bind:value={$formData.custom_charset_4}
                                placeholder="!@#$%^&*()" />
                        </div>
                    </div>
                </div>
            </div>
        {:else if $formData.attack_mode === 'brute_force'}
            <div class="space-y-4">
                <div class="grid grid-cols-2 gap-4">
                    <div class="space-y-2">
                        <Label for="increment_minimum">Minimum Length</Label>
                        <Input
                            id="increment_minimum"
                            type="number"
                            bind:value={$formData.increment_minimum}
                            placeholder="1" />
                    </div>
                    <div class="space-y-2">
                        <Label for="increment_maximum">Maximum Length</Label>
                        <Input
                            id="increment_maximum"
                            type="number"
                            bind:value={$formData.increment_maximum}
                            placeholder="8" />
                    </div>
                </div>

                <div class="space-y-4">
                    <Label>Character Sets</Label>
                    <div class="grid grid-cols-2 gap-4">
                        <div class="flex items-center space-x-2">
                            <Checkbox
                                id="charset_lowercase"
                                bind:checked={$formData.charset_lowercase} />
                            <Label for="charset_lowercase">Lowercase (a-z)</Label>
                        </div>
                        <div class="flex items-center space-x-2">
                            <Checkbox
                                id="charset_uppercase"
                                bind:checked={$formData.charset_uppercase} />
                            <Label for="charset_uppercase">Uppercase (A-Z)</Label>
                        </div>
                        <div class="flex items-center space-x-2">
                            <Checkbox id="charset_digits" bind:checked={$formData.charset_digits} />
                            <Label for="charset_digits">Digits (0-9)</Label>
                        </div>
                        <div class="flex items-center space-x-2">
                            <Checkbox
                                id="charset_special"
                                bind:checked={$formData.charset_special} />
                            <Label for="charset_special">Special Characters</Label>
                        </div>
                    </div>
                </div>
            </div>
        {/if}
    </CardContent>
</Card>
