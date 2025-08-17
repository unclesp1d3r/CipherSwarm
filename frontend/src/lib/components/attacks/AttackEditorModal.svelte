<script lang="ts">
    import { createEventDispatcher } from 'svelte';
    import { Dialog, DialogContent, DialogHeader, DialogTitle } from '$lib/components/ui/dialog';
    import { Button } from '$lib/components/ui/button';
    import { Input } from '$lib/components/ui/input';
    import { Label } from '$lib/components/ui/label';
    import { Select, SelectContent, SelectItem, SelectTrigger } from '$lib/components/ui/select';
    import { Textarea } from '$lib/components/ui/textarea';
    import { RadioGroup, RadioGroupItem } from '$lib/components/ui/radio-group';
    import { Checkbox } from '$lib/components/ui/checkbox';
    import { Badge } from '$lib/components/ui/badge';
    import { Alert, AlertDescription } from '$lib/components/ui/alert';
    import { Card, CardContent } from '$lib/components/ui/card';
    import { CircleIcon, CircleDotIcon } from '@lucide/svelte';
    import BruteForcePreview from './BruteForcePreview.svelte';
    import AttackEstimate from './AttackEstimate.svelte';
    import RuleExplanationModal from './RuleExplanationModal.svelte';
    import AttackEditWarning from './AttackEditWarning.svelte';
    import axios from 'axios';

    export let open = false;
    export let attack: Attack | null = null;

    interface Attack {
        id?: number;
        attack_mode?: string;
        name?: string;
        mask?: string;
        min_length?: number;
        max_length?: number;
        wordlist_source?: string;
        word_list_id?: string;
        rule_list_id?: string;
        language?: string;
        modifiers?: string[];
        custom_charset_1?: string;
        custom_charset_2?: string;
        custom_charset_3?: string;
        custom_charset_4?: string;
        charset_lowercase?: boolean;
        charset_uppercase?: boolean;
        charset_digits?: boolean;
        charset_special?: boolean;
        increment_minimum?: number;
        increment_maximum?: number;
        masks_inline?: string[];
        wordlist_inline?: string[];
        type?: string;
        comment?: string;
        description?: string;
        state?: string;
        created_at?: string;
        updated_at?: string;
        [key: string]: unknown;
    }

    interface ResourceFile {
        id: string;
        name: string;
        type: string;
        file_size?: number;
        description?: string;
    }

    interface AttackEstimate {
        keyspace: number;
        complexity_score: number;
    }

    let attackMode = attack?.attack_mode || 'dictionary';
    let name = attack?.name || '';
    let comment = attack?.comment || '';
    let mask = attack?.mask || '';
    let minLength = attack?.min_length || 1;
    let maxLength = attack?.max_length || 32;
    let wordlistSource = attack?.wordlist_source || 'existing';
    let selectedWordlistId = attack?.word_list_id || '';
    let selectedRuleListId = attack?.rule_list_id || '';
    let language = attack?.language || 'english';
    let modifiers: string[] = attack?.modifiers || [];
    let customCharset1 = attack?.custom_charset_1 || '';
    let customCharset2 = attack?.custom_charset_2 || '';
    let customCharset3 = attack?.custom_charset_3 || '';
    let customCharset4 = attack?.custom_charset_4 || '';

    // Brute force settings
    let charsetLowercase = attack?.charset_lowercase ?? true;
    let charsetUppercase = attack?.charset_uppercase ?? true;
    let charsetDigits = attack?.charset_digits ?? true;
    let charsetSpecial = attack?.charset_special ?? true;
    let incrementMinimum = attack?.increment_minimum || 1;
    let incrementMaximum = attack?.increment_maximum || 8;

    // Dynamic lists
    let maskLines: string[] = attack?.masks_inline || [''];
    let wordlistInline: string[] = attack?.wordlist_inline || [''];

    // Resources
    let wordlists: ResourceFile[] = [];
    let rulelists: ResourceFile[] = [];
    let loading = false;
    let estimate: AttackEstimate | null = null;
    let errors: Array<{ msg: string; loc?: string[] }> = [];
    let showValidation = false;
    let showRuleExplanation = false;
    let showEditWarning = false;

    const dispatch = createEventDispatcher();

    // Reactive statements
    $: if (open) {
        loadResources();
        if (attackMode) {
            estimateAttack();
        }
    }

    $: builtCharset = buildCharset(
        charsetLowercase,
        charsetUppercase,
        charsetDigits,
        charsetSpecial,
        attackMode
    );
    $: generatedMask = buildMask(attackMode, incrementMaximum);

    async function loadResources() {
        try {
            const [wordlistResponse, rulelistResponse] = await Promise.all([
                axios.get('/api/v1/web/resources?type=word_list'),
                axios.get('/api/v1/web/resources?type=rule_list'),
            ]);
            wordlists = wordlistResponse.data.resources || [];
            rulelists = rulelistResponse.data.resources || [];
        } catch (e) {
            console.error('Failed to load resources:', e);
        }
    }

    async function estimateAttack() {
        if (!attackMode) return;

        try {
            const payload = buildSubmissionData();
            const response = await axios.post('/api/v1/web/attacks/estimate', payload);
            estimate = response.data;
        } catch (e) {
            console.error('Failed to estimate attack:', e);
            estimate = null;
        }
    }

    function buildCharset(
        lowercase: boolean,
        uppercase: boolean,
        digits: boolean,
        special: boolean,
        mode: string
    ): string {
        if (mode !== 'brute_force') return '';

        let charset = '';
        if (lowercase) charset += '?l';
        if (uppercase) charset += '?u';
        if (digits) charset += '?d';
        if (special) charset += '?s';
        return charset;
    }

    function buildMask(mode: string, maxLength: number): string {
        if (mode !== 'brute_force') return '';
        return '?1'.repeat(maxLength);
    }

    function buildSubmissionData() {
        const data: Record<string, unknown> = {
            name,
            attack_mode: attackMode,
            attack_mode_hashcat: getHashcatMode(),
        };

        if (attackMode === 'dictionary') {
            data.min_length = minLength;
            data.max_length = maxLength;
            if (wordlistSource === 'existing' && selectedWordlistId) {
                data.word_list_id = selectedWordlistId;
            } else if (wordlistSource === 'previous_passwords') {
                data.use_previous_passwords = true;
            }
            if (wordlistInline.filter((w) => w.trim()).length > 0) {
                data.wordlist_inline = wordlistInline.filter((w) => w.trim());
            }
            if (selectedRuleListId) {
                data.rule_list_id = selectedRuleListId;
            }
            if (modifiers.length > 0) {
                data.modifiers = modifiers;
            }
        } else if (attackMode === 'mask') {
            data.mask = mask;
            data.language = language;
            if (maskLines.filter((m) => m.trim()).length > 0) {
                data.masks_inline = maskLines.filter((m) => m.trim());
            }
            if (customCharset1) data.custom_charset_1 = customCharset1;
            if (customCharset2) data.custom_charset_2 = customCharset2;
            if (customCharset3) data.custom_charset_3 = customCharset3;
            if (customCharset4) data.custom_charset_4 = customCharset4;
        } else if (attackMode === 'brute_force') {
            data.increment_mode = true;
            data.increment_minimum = incrementMinimum;
            data.increment_maximum = incrementMaximum;
            data.mask = generatedMask;
            data.custom_charset_1 = builtCharset;
        }

        return data;
    }

    function getHashcatMode(): number {
        switch (attackMode) {
            case 'dictionary':
                return 0;
            case 'mask':
                return 3;
            case 'brute_force':
                return 3;
            default:
                return 0;
        }
    }

    function addMaskLine() {
        maskLines = [...maskLines, ''];
    }

    function removeMaskLine(index: number) {
        maskLines = maskLines.filter((_, i) => i !== index);
        if (maskLines.length === 0) maskLines = [''];
    }

    function addWordInline() {
        wordlistInline = [...wordlistInline, ''];
    }

    function removeWordInline(index: number) {
        wordlistInline = wordlistInline.filter((_, i) => i !== index);
        if (wordlistInline.length === 0) wordlistInline = [''];
    }

    function toggleModifier(modifier: string) {
        if (modifiers.includes(modifier)) {
            modifiers = modifiers.filter((m) => m !== modifier);
        } else {
            modifiers = [...modifiers, modifier];
        }
        estimateAttack();
    }

    function getModifierButtons() {
        return [
            {
                id: 'change_case',
                label: '+ Change Case',
                description: 'Add uppercase, lowercase, capitalize transformations',
            },
            {
                id: 'substitute_chars',
                label: '+ Substitute Characters',
                description: 'Add leetspeak and character substitutions',
            },
            {
                id: 'change_order',
                label: '+ Change Order',
                description: 'Add reverse and duplicate transformations',
            },
        ];
    }

    function renderComplexityDots(score: number) {
        const dots = [];
        for (let i = 1; i <= 5; i++) {
            dots.push(i <= score);
        }
        return dots;
    }

    function formatKeyspace(keyspace: number): string {
        if (keyspace > 1e12) {
            return `${(keyspace / 1e12).toFixed(1)}T`;
        } else if (keyspace > 1e9) {
            return `${(keyspace / 1e9).toFixed(1)}B`;
        } else if (keyspace > 1e6) {
            return `${(keyspace / 1e6).toFixed(1)}M`;
        } else if (keyspace > 1e3) {
            return `${(keyspace / 1e3).toFixed(1)}K`;
        }
        return keyspace.toLocaleString();
    }

    async function handleSubmit(event: SubmitEvent) {
        event.preventDefault();
        loading = true;
        errors = [];
        showValidation = true;

        // Client-side validation
        if (!name.trim()) {
            errors = [{ msg: 'Attack name is required', loc: ['name'] }];
            loading = false;
            showValidation = true;
            return;
        }

        try {
            const data = buildSubmissionData();

            if (attack) {
                // Edit existing attack
                await axios.put(`/api/v1/web/attacks/${attack.id}`, data);
            } else {
                // Create new attack
                await axios.post('/api/v1/web/attacks/', data);
            }

            // Reset form and close modal
            resetForm();
            open = false;
            dispatch('success');
        } catch (e: unknown) {
            const error = e as { response?: { data?: { detail?: unknown } } };
            if (error.response?.data?.detail) {
                const detail = error.response.data.detail;
                errors = Array.isArray(detail)
                    ? (detail as Array<{ msg: string; loc?: string[] }>)
                    : [{ msg: String(detail) }];
            } else {
                errors = [{ msg: 'Failed to save attack. Please try again.' }];
            }
        } finally {
            loading = false;
        }
    }

    function handleCancel() {
        open = false;
        dispatch('cancel');
    }

    function resetForm() {
        attackMode = 'dictionary';
        name = '';
        comment = '';
        mask = '';
        minLength = 1;
        maxLength = 32;
        wordlistSource = 'existing';
        selectedWordlistId = '';
        selectedRuleListId = '';
        language = 'english';
        modifiers = [];
        customCharset1 = '';
        customCharset2 = '';
        customCharset3 = '';
        customCharset4 = '';
        charsetLowercase = true;
        charsetUppercase = true;
        charsetDigits = true;
        charsetSpecial = true;
        incrementMinimum = 1;
        incrementMaximum = 8;
        maskLines = [''];
        wordlistInline = [''];
        showValidation = false;
        errors = [];
        estimate = null;
        showRuleExplanation = false;
        showEditWarning = false;
    }

    // Reset form when modal opens/closes
    $: if (!open && !attack) {
        resetForm();
    }

    // Populate form when attack changes and modal is open
    $: if (open && attack) {
        attackMode = attack.attack_mode || 'dictionary';
        name = attack.name || '';
        comment = attack.comment || '';
        mask = attack.mask || '';
        minLength = attack.min_length || 1;
        maxLength = attack.max_length || 32;
        wordlistSource = attack.wordlist_source || 'existing';
        selectedWordlistId = attack.word_list_id || '';
        selectedRuleListId = attack.rule_list_id || '';
        language = attack.language || 'english';
        modifiers = attack.modifiers || [];
        customCharset1 = attack.custom_charset_1 || '';
        customCharset2 = attack.custom_charset_2 || '';
        customCharset3 = attack.custom_charset_3 || '';
        customCharset4 = attack.custom_charset_4 || '';
        charsetLowercase = attack.charset_lowercase ?? true;
        charsetUppercase = attack.charset_uppercase ?? true;
        charsetDigits = attack.charset_digits ?? true;
        charsetSpecial = attack.charset_special ?? false;
        incrementMinimum = attack.increment_minimum || 1;
        incrementMaximum = attack.increment_maximum || 8;
        maskLines = attack.masks_inline || [''];
        wordlistInline = attack.wordlist_inline || [''];
    } else if (!attack && open) {
        attackMode = 'dictionary';
        name = '';
        comment = '';
        mask = '';
        minLength = 1;
        maxLength = 32;
        wordlistSource = 'existing';
        selectedWordlistId = '';
        selectedRuleListId = '';
        language = 'english';
        modifiers = [];
        customCharset1 = '';
        customCharset2 = '';
        customCharset3 = '';
        customCharset4 = '';
        charsetLowercase = true;
        charsetUppercase = true;
        charsetDigits = true;
        charsetSpecial = true;
        incrementMinimum = 1;
        incrementMaximum = 8;
        maskLines = [''];
        wordlistInline = [''];
    }

    // Check if we need to show edit warning for running/exhausted attacks
    $: if (open && attack && (attack.state === 'running' || attack.state === 'exhausted')) {
        showEditWarning = true;
    }

    // Re-estimate when key fields change
    $: if (
        attackMode ||
        minLength ||
        maxLength ||
        selectedWordlistId ||
        incrementMinimum ||
        incrementMaximum ||
        charsetLowercase ||
        charsetUppercase ||
        charsetDigits ||
        charsetSpecial
    ) {
        if (open) estimateAttack();
    }

    function handleEditWarningConfirm() {
        showEditWarning = false;
    }

    function handleEditWarningCancel() {
        showEditWarning = false;
        open = false;
        dispatch('cancel');
    }
</script>

<Dialog bind:open>
    <DialogContent class="max-h-[90vh] max-w-2xl overflow-y-auto">
        <DialogHeader>
            <DialogTitle>{attack ? 'Edit' : 'Create'} Attack</DialogTitle>
        </DialogHeader>

        {#if showEditWarning}
            <AttackEditWarning
                attackName={attack?.name || 'Unknown Attack'}
                onconfirm={handleEditWarningConfirm}
                oncancel={handleEditWarningCancel} />
        {/if}

        <form on:submit|preventDefault={handleSubmit} class="space-y-6">
            <!-- General Settings -->
            <div class="space-y-4">
                <div>
                    <Label for="name">Name</Label>
                    <Input id="name" bind:value={name} placeholder="Enter attack name" required />
                    {#if errors.find((e) => e.loc?.[0] === 'name') || name.trim() === ''}
                        <p class="mt-1 text-sm text-red-600" data-testid="error-name-required">
                            Attack name is required
                        </p>
                    {/if}
                </div>

                <div>
                    <Label for="comment">Comment</Label>
                    <Input id="comment" bind:value={comment} placeholder="Optional comment" />
                </div>

                <div>
                    <Label for="attack_mode">Attack Mode</Label>
                    <div class="mt-2 flex gap-2">
                        <Button
                            type="button"
                            variant={attackMode === 'dictionary' ? 'default' : 'outline'}
                            data-testid="attack-mode-dictionary"
                            aria-label="Attack Mode: Dictionary"
                            onclick={() => (attackMode = 'dictionary')}>
                            Dictionary Mode
                        </Button>
                        <Button
                            type="button"
                            variant={attackMode === 'mask' ? 'default' : 'outline'}
                            data-testid="attack-mode-mask"
                            aria-label="Attack Mode: Mask"
                            onclick={() => (attackMode = 'mask')}>
                            Mask Mode
                        </Button>
                        <Button
                            type="button"
                            variant={attackMode === 'brute_force' ? 'default' : 'outline'}
                            data-testid="attack-mode-brute-force"
                            aria-label="Attack Mode: Brute Force"
                            onclick={() => (attackMode = 'brute_force')}>
                            Brute Force Mode
                        </Button>
                    </div>
                    {#each errors.filter((e) => e.loc?.[0] === 'attack_mode') as error, i (i)}
                        <p class="mt-1 text-sm text-red-600">{error.msg}</p>
                    {/each}
                </div>
            </div>

            <!-- Dictionary Attack Settings -->
            {#if attackMode === 'dictionary'}
                <Card>
                    <CardContent class="space-y-4 pt-6">
                        <h3 class="font-medium" data-testid="section-dictionary-settings">
                            Dictionary Attack Settings
                        </h3>

                        <!-- Length Range -->
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <Label for="min_length">Min Length</Label>
                                <Input
                                    id="min_length"
                                    type="number"
                                    bind:value={minLength}
                                    min="1"
                                    max="128" />
                            </div>
                            <div>
                                <Label for="max_length">Max Length</Label>
                                <Input
                                    id="max_length"
                                    type="number"
                                    bind:value={maxLength}
                                    min="1"
                                    max="128" />
                            </div>
                        </div>

                        <!-- Wordlist Source -->
                        <div>
                            <Label>Wordlist Source</Label>
                            <RadioGroup bind:value={wordlistSource} class="mt-2">
                                <div class="flex items-center space-x-2">
                                    <RadioGroupItem value="existing" id="existing" />
                                    <Label for="existing">Existing Wordlist</Label>
                                </div>
                                <div class="flex items-center space-x-2">
                                    <RadioGroupItem
                                        value="previous_passwords"
                                        id="previous_passwords" />
                                    <Label for="previous_passwords">Previous Passwords</Label>
                                </div>
                            </RadioGroup>
                        </div>

                        {#if wordlistSource === 'existing'}
                            <div>
                                <Label for="wordlist">Wordlist</Label>
                                <Select type="single" bind:value={selectedWordlistId}>
                                    <SelectTrigger>
                                        {selectedWordlistId
                                            ? wordlists.find((w) => w.id === selectedWordlistId)
                                                  ?.name || 'Select wordlist'
                                            : 'Select wordlist'}
                                    </SelectTrigger>
                                    <SelectContent>
                                        {#each wordlists as wordlist (wordlist.id)}
                                            <SelectItem value={wordlist.id}>
                                                {wordlist.name}
                                                {#if wordlist.file_size}
                                                    ({(wordlist.file_size / 1024).toFixed(1)}KB)
                                                {/if}
                                            </SelectItem>
                                        {/each}
                                    </SelectContent>
                                </Select>
                            </div>

                            <!-- Ephemeral Wordlist -->
                            <div>
                                <Label>Ephemeral Wordlist (Add Words)</Label>
                                <div class="space-y-2">
                                    {#each wordlistInline as word, idx (idx)}
                                        <div class="flex gap-2">
                                            <Input
                                                bind:value={wordlistInline[idx]}
                                                placeholder="Enter word" />
                                            <Button
                                                type="button"
                                                variant="outline"
                                                size="sm"
                                                onclick={() => removeWordInline(idx)}>
                                                ×
                                            </Button>
                                        </div>
                                    {/each}
                                    <Button
                                        type="button"
                                        variant="outline"
                                        size="sm"
                                        onclick={addWordInline}>
                                        + Add Word
                                    </Button>
                                </div>
                            </div>
                        {:else if wordlistSource === 'previous_passwords'}
                            <Alert>
                                <AlertDescription>
                                    Uses all previously cracked passwords for this project. No
                                    manual wordlist selection required.
                                </AlertDescription>
                            </Alert>
                        {/if}

                        <!-- Rule List -->
                        <div>
                            <div class="flex items-center justify-between">
                                <Label for="rulelist">Rule List (Optional)</Label>
                                <Button
                                    type="button"
                                    variant="outline"
                                    size="sm"
                                    onclick={() => (showRuleExplanation = true)}>
                                    ? Rule Help
                                </Button>
                            </div>
                            <Select type="single" bind:value={selectedRuleListId}>
                                <SelectTrigger>
                                    {selectedRuleListId
                                        ? rulelists.find((r) => r.id === selectedRuleListId)
                                              ?.name || 'Select rule list'
                                        : 'Select rule list'}
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="">None</SelectItem>
                                    {#each rulelists as rulelist (rulelist.id)}
                                        <SelectItem value={rulelist.id}>{rulelist.name}</SelectItem>
                                    {/each}
                                </SelectContent>
                            </Select>
                        </div>

                        <!-- Modifiers -->
                        <div>
                            <Label>Modifiers</Label>
                            <div class="mt-2 flex flex-wrap gap-2">
                                {#each getModifierButtons() as button (button.id)}
                                    <Button
                                        type="button"
                                        variant={modifiers.includes(button.id)
                                            ? 'default'
                                            : 'outline'}
                                        size="sm"
                                        onclick={() => toggleModifier(button.id)}>
                                        {button.label}
                                    </Button>
                                {/each}
                            </div>
                            {#if modifiers.length > 0}
                                <div class="mt-2 flex flex-wrap gap-1">
                                    {#each modifiers as modifier, i (i)}
                                        <Badge variant="secondary">{modifier}</Badge>
                                    {/each}
                                </div>
                            {/if}
                        </div>
                    </CardContent>
                </Card>
            {/if}

            <!-- Mask Attack Settings -->
            {#if attackMode === 'mask'}
                <Card>
                    <CardContent class="space-y-4 pt-6">
                        <h3 class="font-medium" data-testid="section-mask-settings">
                            Mask Attack Settings
                        </h3>

                        <div>
                            <Label for="language">Language</Label>
                            <Select type="single" bind:value={language}>
                                <SelectTrigger>
                                    {language || 'Select language'}
                                </SelectTrigger>
                                <SelectContent>
                                    <SelectItem value="english">English</SelectItem>
                                </SelectContent>
                            </Select>
                        </div>

                        <div>
                            <Label for="mask">Mask</Label>
                            <Input
                                id="mask"
                                bind:value={mask}
                                placeholder="e.g., ?u?l?l?l?d?d?d?d" />
                        </div>

                        <!-- Inline Masks -->
                        <div>
                            <Label>Masks</Label>
                            <div class="space-y-2">
                                {#each maskLines as maskLine, idx (idx)}
                                    <div class="flex gap-2">
                                        <Input
                                            bind:value={maskLines[idx]}
                                            placeholder="Enter mask pattern" />
                                        <Button
                                            type="button"
                                            variant="outline"
                                            size="sm"
                                            onclick={() => removeMaskLine(idx)}>
                                            ×
                                        </Button>
                                    </div>
                                {/each}
                                <Button
                                    type="button"
                                    variant="outline"
                                    size="sm"
                                    onclick={addMaskLine}>
                                    + Add Mask
                                </Button>
                            </div>
                        </div>

                        <!-- Custom Symbol Sets -->
                        <div>
                            <Label>Custom Symbol Sets</Label>
                            <div class="space-y-2">
                                <Input bind:value={customCharset1} placeholder="Set 1 (?1)" />
                                <Input bind:value={customCharset2} placeholder="Set 2 (?2)" />
                                <Input bind:value={customCharset3} placeholder="Set 3 (?3)" />
                                <Input bind:value={customCharset4} placeholder="Set 4 (?4)" />
                            </div>
                        </div>
                    </CardContent>
                </Card>
            {/if}

            <!-- Brute Force Attack Settings -->
            {#if attackMode === 'brute_force'}
                <Card>
                    <CardContent class="space-y-4 pt-6">
                        <h3 class="font-medium" data-testid="section-brute-force-settings">
                            Brute Force Character Sets
                        </h3>

                        <!-- Length Range -->
                        <div class="grid grid-cols-2 gap-4">
                            <div>
                                <Label for="increment_minimum">Min Length</Label>
                                <Input
                                    id="increment_minimum"
                                    type="number"
                                    bind:value={incrementMinimum}
                                    min="1"
                                    max="64" />
                            </div>
                            <div>
                                <Label for="increment_maximum">Max Length</Label>
                                <Input
                                    id="increment_maximum"
                                    type="number"
                                    bind:value={incrementMaximum}
                                    min="1"
                                    max="64" />
                            </div>
                        </div>

                        <!-- Character Sets -->
                        <div>
                            <Label>Character Sets</Label>
                            <div class="mt-2 grid grid-cols-2 gap-2">
                                <div class="flex items-center space-x-2">
                                    <Checkbox id="lowercase" bind:checked={charsetLowercase} />
                                    <Label for="lowercase">Lowercase (a-z)</Label>
                                </div>
                                <div class="flex items-center space-x-2">
                                    <Checkbox id="uppercase" bind:checked={charsetUppercase} />
                                    <Label for="uppercase">Uppercase (A-Z)</Label>
                                </div>
                                <div class="flex items-center space-x-2">
                                    <Checkbox id="digits" bind:checked={charsetDigits} />
                                    <Label for="digits">Digits (0-9)</Label>
                                </div>
                                <div class="flex items-center space-x-2">
                                    <Checkbox id="special" bind:checked={charsetSpecial} />
                                    <Label for="special">Symbols (!@#$)</Label>
                                </div>
                            </div>
                        </div>

                        <!-- Charset Preview -->
                        <BruteForcePreview customCharset={builtCharset} mask={generatedMask} />
                    </CardContent>
                </Card>
            {/if}

            <!-- Estimate Display -->
            {#if estimate}
                <AttackEstimate
                    keyspace={estimate.keyspace}
                    complexityScore={estimate.complexity_score} />
            {/if}

            <!-- Error Display -->
            {#if errors.length > 0}
                <Alert variant="destructive">
                    <AlertDescription>
                        {#if errors.length === 1}
                            {errors[0].msg}
                        {:else}
                            <ul class="list-inside list-disc">
                                {#each errors as error, i (i)}
                                    <li>{error.msg}</li>
                                {/each}
                            </ul>
                        {/if}
                    </AlertDescription>
                </Alert>
            {/if}

            <!-- Form Actions -->
            <div class="flex justify-end gap-2">
                <Button type="button" variant="outline" onclick={handleCancel}>Cancel</Button>
                <Button type="submit" disabled={loading}>
                    {loading ? 'Saving...' : attack ? 'Update Attack' : 'Add Attack'}
                </Button>
            </div>
        </form>
    </DialogContent>
</Dialog>

<!-- Rule Explanation Modal -->
<RuleExplanationModal bind:open={showRuleExplanation} />
