// Attack type icon mappings using Lucide icons
export const ATTACK_TYPE_ICONS = {
  dictionary: 'book-open',
  mask: 'command', 
  brute_force: 'hash',
  hybrid: 'merge',
  previous_passwords: 'rotate-ccw',
  rule_based: 'sliders-horizontal',
  combinator: 'puzzle',
  wordlist: 'list',
  
  // Additional common icons for UI elements
  success: 'check-circle',
  warning: 'alert-triangle',
  error: 'x-circle',
  info: 'info',
  loading: 'loader-2',
  edit: 'edit',
  delete: 'trash-2',
  add: 'plus',
  download: 'download',
  upload: 'upload',
  settings: 'settings',
  user: 'user',
  users: 'users',
  folder: 'folder',
  file: 'file',
  eye: 'eye',
  eye_off: 'eye-off',
  chevron_down: 'chevron-down',
  chevron_up: 'chevron-up',
  chevron_left: 'chevron-left',
  chevron_right: 'chevron-right',
  menu: 'menu',
  close: 'x',
  search: 'search',
  filter: 'filter',
  copy: 'copy',
  external_link: 'external-link',
  refresh: 'refresh-cw',
} as const;

export type AttackTypeIcon = keyof typeof ATTACK_TYPE_ICONS;

/**
 * Get the icon name for a specific attack type
 */
export function getAttackTypeIcon(attackType: string): string {
  return ATTACK_TYPE_ICONS[attackType as keyof typeof ATTACK_TYPE_ICONS] || 'help-circle';
}

/**
 * Get semantic color classes for different states
 */
export function getSemanticColors(type: 'success' | 'warning' | 'error' | 'info'): string {
  switch (type) {
    case 'success':
      return 'text-green-500 dark:text-green-400';
    case 'warning': 
      return 'text-yellow-500 dark:text-yellow-400';
    case 'error':
      return 'text-red-500 dark:text-red-400';
    case 'info':
      return 'text-blue-500 dark:text-blue-400';
    default:
      return 'text-foreground';
  }
}