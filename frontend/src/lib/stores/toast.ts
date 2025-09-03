import { writable } from 'svelte/store';

export interface Toast {
  id: string;
  type: 'success' | 'error' | 'warning' | 'info';
  title: string;
  message?: string;
  duration?: number; // Duration in milliseconds, 0 for persistent
  dismissible?: boolean;
}

interface ToastStore {
  toasts: Toast[];
  add: (toast: Omit<Toast, 'id'>) => void;
  remove: (id: string) => void;
  clear: () => void;
}

function createToastStore(): ToastStore {
  const { subscribe, update } = writable<Toast[]>([]);

  function generateId(): string {
    return Math.random().toString(36).substr(2, 9);
  }

  function add(toast: Omit<Toast, 'id'>) {
    const id = generateId();
    const newToast: Toast = {
      id,
      dismissible: true,
      duration: 5000, // Default 5 seconds
      ...toast,
    };

    update(toasts => [...toasts, newToast]);

    // Auto-remove after duration if not persistent
    if (newToast.duration && newToast.duration > 0) {
      setTimeout(() => {
        remove(id);
      }, newToast.duration);
    }
  }

  function remove(id: string) {
    update(toasts => toasts.filter(toast => toast.id !== id));
  }

  function clear() {
    update(() => []);
  }

  return {
    subscribe,
    add,
    remove,
    clear,
    get toasts() {
      let current: Toast[] = [];
      subscribe(value => current = value)();
      return current;
    }
  };
}

export const toastStore = createToastStore();

// Convenience functions for different toast types
export const toast = {
  success: (title: string, message?: string, duration?: number) => 
    toastStore.add({ type: 'success', title, message, duration }),
  
  error: (title: string, message?: string, duration?: number) => 
    toastStore.add({ type: 'error', title, message, duration: duration || 0 }), // Errors persist by default
  
  warning: (title: string, message?: string, duration?: number) => 
    toastStore.add({ type: 'warning', title, message, duration }),
  
  info: (title: string, message?: string, duration?: number) => 
    toastStore.add({ type: 'info', title, message, duration }),
};