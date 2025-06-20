export interface User {
    id: string;
    email: string;
    name: string;
    is_active: boolean;
    is_superuser: boolean;
    created_at: string;
    updated_at: string;
    role: string;
}

export interface UserCreate {
    email: string;
    name: string;
    password: string;
}

export interface UserUpdate {
    email?: string;
    name?: string;
    password?: string;
    role?: string;
}
