<script lang="ts">
    import { Button } from '$lib/components/ui/button';
    import { Dialog, DialogContent, DialogHeader, DialogTitle } from '$lib/components/ui/dialog';
    import {
        Table,
        TableBody,
        TableCell,
        TableHead,
        TableHeader,
        TableRow,
    } from '$lib/components/ui/table';
    import { X } from '@lucide/svelte';
    import { createEventDispatcher } from 'svelte';

    export let open = false;

    const dispatch = createEventDispatcher<{
        close: void;
    }>();

    function closeModal() {
        dispatch('close');
    }

    // Common hashcat rules with explanations
    const ruleExplanations = [
        { rule: ':', desc: 'Do nothing (no-op)' },
        { rule: 'l', desc: 'Lowercase all letters' },
        { rule: 'u', desc: 'Uppercase all letters' },
        { rule: 'c', desc: 'Capitalize first letter, lowercase rest' },
        { rule: 'C', desc: 'Lowercase first letter, uppercase rest' },
        { rule: 't', desc: 'Toggle case of all letters' },
        { rule: 'TN', desc: 'Toggle case of character at position N' },
        { rule: 'r', desc: 'Reverse the word' },
        { rule: 'd', desc: 'Duplicate the word' },
        { rule: 'f', desc: 'Reflect the word (duplicate and reverse)' },
        { rule: '{', desc: 'Rotate word left' },
        { rule: '}', desc: 'Rotate word right' },
        { rule: '$X', desc: 'Append character X' },
        { rule: '^X', desc: 'Prepend character X' },
        { rule: '[', desc: 'Delete first character' },
        { rule: ']', desc: 'Delete last character' },
        { rule: 'DN', desc: 'Delete character at position N' },
        { rule: 'xNM', desc: 'Extract substring from position N for M characters' },
        { rule: 'iNX', desc: 'Insert character X at position N' },
        { rule: 'oNX', desc: 'Overwrite character at position N with X' },
        { rule: 'sXY', desc: 'Replace all instances of X with Y' },
        { rule: '@X', desc: 'Purge all instances of character X' },
        { rule: '!X', desc: 'Reject word if it contains character X' },
        { rule: '/X', desc: 'Reject word if it does not contain character X' },
        { rule: '=NX', desc: 'Reject word if character at position N is not X' },
        { rule: '(X', desc: 'Reject word if it does not start with X' },
        { rule: ')X', desc: 'Reject word if it does not end with X' },
        { rule: '%NX', desc: 'Reject word if character at position N is X' },
        { rule: 'z2', desc: 'Duplicate first character' },
        { rule: 'Z2', desc: 'Duplicate last character' },
        { rule: 'p2', desc: 'Duplicate first 2 characters' },
        { rule: 'P2', desc: 'Duplicate last 2 characters' },
    ];
</script>

<Dialog bind:open>
    <DialogContent class="max-w-2xl">
        <DialogHeader class="flex flex-row items-center justify-between">
            <DialogTitle>Hashcat Rule Syntax - Common Rules</DialogTitle>
            <Button variant="ghost" size="icon" onclick={closeModal} class="h-6 w-6">
                <X class="h-4 w-4" />
            </Button>
        </DialogHeader>
        <div class="max-h-96 overflow-y-auto">
            <Table>
                <TableHeader>
                    <TableRow>
                        <TableHead class="w-20">Rule</TableHead>
                        <TableHead>Explanation</TableHead>
                    </TableRow>
                </TableHeader>
                <TableBody>
                    {#each ruleExplanations as rule (rule.rule)}
                        <TableRow>
                            <TableCell class="font-mono text-sm">{rule.rule}</TableCell>
                            <TableCell class="text-sm">{rule.desc}</TableCell>
                        </TableRow>
                    {/each}
                </TableBody>
            </Table>
        </div>
    </DialogContent>
</Dialog>
