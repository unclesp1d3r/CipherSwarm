<script lang="ts">
    import { Card, CardContent, CardHeader, CardTitle } from '$lib/components/ui/card';
    import { Button } from '$lib/components/ui/button';
    import { Input } from '$lib/components/ui/input';
    import { Label } from '$lib/components/ui/label';
    import { Separator } from '$lib/components/ui/separator';
    import { Badge } from '$lib/components/ui/badge';
    import { Alert, AlertDescription } from '$lib/components/ui/alert';
    import { toast } from '$lib/utils/toast';
    import type { User } from '$lib/types/user';
    import { createEventDispatcher } from 'svelte';

    export let user: User;

    const dispatch = createEventDispatcher<{
        passwordChanged: void;
    }>();

    let passwordForm = {
        old_password: '',
        new_password: '',
        new_password_confirm: '',
    };

    let isChangingPassword = false;
    let passwordError = '';

    function formatDate(dateString: string): string {
        return new Date(dateString).toLocaleString();
    }

    async function handlePasswordChange() {
        passwordError = '';

        // Client-side validation
        if (passwordForm.new_password !== passwordForm.new_password_confirm) {
            passwordError = 'New passwords do not match';
            return;
        }

        if (passwordForm.new_password.length < 10) {
            passwordError = 'New password must be at least 10 characters long';
            return;
        }

        isChangingPassword = true;

        try {
            const response = await fetch('/api/v1/web/auth/change_password', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    old_password: passwordForm.old_password,
                    new_password: passwordForm.new_password,
                    new_password_confirm: passwordForm.new_password_confirm,
                }),
            });

            if (response.ok) {
                toast.success('Password changed successfully');
                passwordForm = {
                    old_password: '',
                    new_password: '',
                    new_password_confirm: '',
                };
                dispatch('passwordChanged');
            } else {
                const error = await response.json();
                passwordError = error.detail || 'Failed to change password';
            }
        } catch (error) {
            passwordError = 'Network error occurred';
        } finally {
            isChangingPassword = false;
        }
    }
</script>

<div class="mx-auto max-w-2xl space-y-6">
    <!-- Profile Details Card -->
    <Card>
        <CardHeader>
            <CardTitle>Profile Details</CardTitle>
        </CardHeader>
        <CardContent class="space-y-4">
            <div class="grid grid-cols-1 gap-4 md:grid-cols-2">
                <div class="space-y-2">
                    <Label class="text-muted-foreground text-sm font-medium">Name</Label>
                    <p class="text-sm">{user.name}</p>
                </div>
                <div class="space-y-2">
                    <Label class="text-muted-foreground text-sm font-medium">Email</Label>
                    <p class="text-sm">{user.email}</p>
                </div>
                <div class="space-y-2">
                    <Label class="text-muted-foreground text-sm font-medium">Status</Label>
                    <div class="flex gap-2">
                        <Badge variant={user.is_active ? 'default' : 'secondary'}>
                            {user.is_active ? 'Active' : 'Inactive'}
                        </Badge>
                        {#if user.is_superuser}
                            <Badge variant="destructive">Superuser</Badge>
                        {/if}
                    </div>
                </div>
                <div class="space-y-2">
                    <Label class="text-muted-foreground text-sm font-medium">Role</Label>
                    <p class="text-sm">{user.role}</p>
                </div>
                <div class="space-y-2">
                    <Label class="text-muted-foreground text-sm font-medium">Created</Label>
                    <p class="text-sm">{formatDate(user.created_at)}</p>
                </div>
                <div class="space-y-2">
                    <Label class="text-muted-foreground text-sm font-medium">Last Updated</Label>
                    <p class="text-sm">{formatDate(user.updated_at)}</p>
                </div>
            </div>
        </CardContent>
    </Card>

    <!-- Password Change Card -->
    <Card>
        <CardHeader>
            <CardTitle>Change Password</CardTitle>
        </CardHeader>
        <CardContent>
            <form on:submit|preventDefault={handlePasswordChange} class="space-y-4">
                {#if passwordError}
                    <Alert variant="destructive">
                        <AlertDescription>{passwordError}</AlertDescription>
                    </Alert>
                {/if}

                <div class="space-y-2">
                    <Label for="old_password">Current Password</Label>
                    <Input
                        id="old_password"
                        type="password"
                        bind:value={passwordForm.old_password}
                        autocomplete="current-password"
                        required
                        disabled={isChangingPassword} />
                </div>

                <div class="space-y-2">
                    <Label for="new_password">New Password</Label>
                    <Input
                        id="new_password"
                        name="new_password"
                        type="password"
                        bind:value={passwordForm.new_password}
                        placeholder="Enter new password"
                        autocomplete="new-password"
                        minlength={10}
                        required
                        disabled={isChangingPassword} />
                </div>

                <div class="space-y-2">
                    <Label for="new_password_confirm">Confirm New Password</Label>
                    <Input
                        id="new_password_confirm"
                        name="new_password_confirm"
                        type="password"
                        bind:value={passwordForm.new_password_confirm}
                        placeholder="Confirm new password"
                        autocomplete="new-password"
                        minlength={10}
                        required
                        disabled={isChangingPassword} />
                </div>

                <Button type="submit" disabled={isChangingPassword} class="w-full">
                    {isChangingPassword ? 'Changing Password...' : 'Change Password'}
                </Button>
            </form>
        </CardContent>
    </Card>
</div>
