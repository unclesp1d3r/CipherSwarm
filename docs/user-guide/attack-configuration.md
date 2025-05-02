# Attack Configuration Guide

This guide covers the configuration of different attack types in CipherSwarm.

## Attack Types

CipherSwarm supports the following attack types:

1. **Dictionary Attack**

    - Uses wordlists
    - Optional rule sets
    - Straight or combination mode

2. **Mask Attack**

    - Custom character sets
    - Pattern-based generation
    - Incremental mode

3. **Hybrid Attack**
    - Combines dictionary and mask
    - Left-side or right-side masks
    - Rule application

## Dictionary Attacks

### Basic Configuration

```yaml
name: "Common Passwords"
type: "dictionary"
config:
    wordlist: "rockyou.txt"
    rules: "best64.rule"
    hash_type: 0 # MD5
    optimize: true
```

### Advanced Options

```yaml
name: "Advanced Dictionary"
type: "dictionary"
config:
    wordlist: "rockyou.txt"
    rules: ["best64.rule", "d3ad0ne.rule"]
    hash_type: 1000 # NTLM
    optimize: true
    options:
        skip: 0
        limit: 1000000
        custom_charset: "?l?d?s"
        min_length: 8
        max_length: 16
        case_permute: true
```

### Combination Attack

```yaml
name: "Combined Words"
type: "dictionary"
config:
    wordlist1: "words1.txt"
    wordlist2: "words2.txt"
    separator: " "
    rules: "best64.rule"
    hash_type: 0
    options:
        min_length: 10
        max_length: 20
```

## Mask Attacks

### Basic Mask

```yaml
name: "Simple Mask"
type: "mask"
config:
    mask: "?d?d?d?d?d?d?d?d" # 8 digits
    hash_type: 0
    increment: false
```

### Custom Character Sets

```yaml
name: "Custom Mask"
type: "mask"
config:
    mask: "?a?b?c?d"
    hash_type: 0
    charsets:
        1: "abcdefghijklmnopqrstuvwxyz" # ?a
        2: "0123456789" # ?b
        3: "@#$%" # ?c
        4: "ABCDEFGHIJKLMNOPQRSTUVWXYZ" # ?d
    increment: true
    min_length: 4
    max_length: 8
```

### Incremental Mask

```yaml
name: "Incremental"
type: "mask"
config:
    base_mask: "?l?l?l?l"
    hash_type: 0
    increment: true
    min_length: 4
    max_length: 8
    options:
        skip: 0
        limit: 1000000000
```

## Hybrid Attacks

### Left-side Dictionary

```yaml
name: "Left Hybrid"
type: "hybrid"
config:
    mode: "dict_mask" # dictionary then mask
    wordlist: "rockyou.txt"
    mask: "?d?d?d?d"
    rules: "best64.rule"
    hash_type: 0
    options:
        min_length: 8
        max_length: 16
```

### Right-side Dictionary

```yaml
name: "Right Hybrid"
type: "hybrid"
config:
    mode: "mask_dict" # mask then dictionary
    wordlist: "rockyou.txt"
    mask: "?d?d?d?d"
    rules: "best64.rule"
    hash_type: 0
    options:
        min_length: 8
        max_length: 16
```

## Performance Options

### Resource Allocation

```yaml
resources:
    max_agents: 5
    min_agents: 1
    workload: 3 # 1-4, higher = more GPU utilization
    optimize: true
    gpu_temp_abort: 90
    gpu_temp_retain: 80
```

### Distribution Settings

```yaml
distribution:
    keyspace_division: "balanced" # or "sequential"
    chunk_size: 1000000
    overlap: 0
    priority: "high" # low, medium, high
```

## Hash Types

Common hash type codes:

| Code | Hash Type   | Example                                                      |
| ---- | ----------- | ------------------------------------------------------------ |
| 0    | MD5         | 5f4dcc3b5aa765d61d8327deb882cf99                             |
| 100  | SHA1        | a94a8fe5ccb19ba61c4c0873d391e987982fbbd3                     |
| 1000 | NTLM        | b4b9b02e6f09a9bd760f388b67351e2b                             |
| 1800 | SHA512crypt | $6$salt$hash                                                 |
| 3200 | bcrypt      | $2a$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LffqmoKYYL.kj.jzm |

## Rule Sets

### Basic Rules

```
# Convert to uppercase
u
# Convert to lowercase
l
# Capitalize
c
# Toggle case
t
```

### Advanced Rules

```
# Append special characters
$1
$2
$3

# Prepend special characters
^1
^2
^3

# Duplicate entire word
d

# Reverse
r
```

### Custom Rules

```
# Custom rule format:
# operation1 operation2 operation3

# Example: uppercase, append 123, reverse
u $1 $2 $3 r

# Example: lowercase, prepend @, append !
l ^@ $!
```

## Optimization Tips

1. **Wordlist Selection**

    - Use targeted wordlists
    - Remove duplicates
    - Sort by probability
    - Compress large lists

2. **Rule Optimization**

    - Start with simple rules
    - Use rule analyzers
    - Remove redundant rules
    - Test rule effectiveness

3. **Mask Optimization**

    - Use probability tables
    - Start with common patterns
    - Limit mask length
    - Use custom charsets

4. **Resource Usage**
    - Balance workload
    - Monitor temperatures
    - Adjust chunk sizes
    - Use appropriate agents

## Example Configurations

### Password Leak Analysis

```yaml
name: "Leak Analysis"
type: "dictionary"
config:
    wordlist: "leaked_passwords.txt"
    rules: ["best64.rule", "toggles.rule"]
    hash_type: 0
    optimize: true
    options:
        min_length: 6
        max_length: 20
        remove_duplicates: true
        case_permute: true
```

### Complex Password Pattern

```yaml
name: "Complex Pattern"
type: "hybrid"
config:
    mode: "dict_mask"
    wordlist: "words.txt"
    mask: "?s?d?d?d?d"
    rules: "leetspeak.rule"
    hash_type: 1000
    options:
        min_length: 10
        max_length: 16
```

### Targeted Attack

```yaml
name: "Targeted"
type: "mask"
config:
    mask: "Company?d?d?d?d!"
    hash_type: 100
    increment: false
    options:
        custom_charset1: "0123456789"
        workload: 3
        optimize: true
```

For more information:

-   [Hashcat Reference](https://hashcat.net/wiki/)
-   [Rule Writing Guide](../development/rules.md)
-   [Performance Tuning](../development/performance.md)
