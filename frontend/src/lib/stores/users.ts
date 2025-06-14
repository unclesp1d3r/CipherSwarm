import { writable } from 'svelte/store';
import type { User } from '../../routes/users/+page.server';

export const users = writable<User[]>([]);
