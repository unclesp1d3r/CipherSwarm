import re
from typing import Any

from app.schemas.attack import AttackCreate

TOKEN_SIZES = {
    "?l": 26,  # lowercase
    "?u": 26,  # uppercase
    "?d": 10,  # digits
    "?s": 33,  # symbols
    "?a": 95,  # all printable
}

# Keyspace bucket thresholds for complexity scoring
KEYSPACE_BUCKET_1 = 1_000_000
KEYSPACE_BUCKET_2 = 100_000_000
KEYSPACE_BUCKET_3 = 10_000_000_000
KEYSPACE_BUCKET_4 = 1_000_000_000_000


class AttackEstimationService:
    @staticmethod
    def estimate_keyspace(attack: AttackCreate, resources: dict[str, Any]) -> int:
        mode = getattr(attack, "attack_mode", None)
        if mode == "dictionary":
            wordlist_size = resources.get("wordlist_size", 0)
            rule_count = resources.get("rule_count", 1)
            return int(wordlist_size * rule_count)
        if mode == "mask":
            mask = getattr(attack, "mask", "") or ""
            custom_charsets = {
                "?1": getattr(attack, "custom_charset_1", "") or "",
                "?2": getattr(attack, "custom_charset_2", "") or "",
                "?3": getattr(attack, "custom_charset_3", "") or "",
                "?4": getattr(attack, "custom_charset_4", "") or "",
            }
            increment = getattr(attack, "increment_mode", False)
            min_len = getattr(attack, "increment_minimum", 0)
            max_len = getattr(attack, "increment_maximum", 0)
            return int(
                AttackEstimationService._estimate_mask(
                    mask, custom_charsets, increment, min_len, max_len
                )
            )
        if mode == "hybrid_dictionary":
            wordlist_size = resources.get("wordlist_size", 0)
            mask = getattr(attack, "mask", "") or ""
            custom_charsets = {
                "?1": getattr(attack, "custom_charset_1", "") or "",
                "?2": getattr(attack, "custom_charset_2", "") or "",
                "?3": getattr(attack, "custom_charset_3", "") or "",
                "?4": getattr(attack, "custom_charset_4", "") or "",
            }
            increment = getattr(attack, "increment_mode", False)
            min_len = getattr(attack, "increment_minimum", 0)
            max_len = getattr(attack, "increment_maximum", 0)
            mask_keyspace = int(
                AttackEstimationService._estimate_mask(
                    mask, custom_charsets, increment, min_len, max_len
                )
            )
            return int(wordlist_size * mask_keyspace)
        if mode == "hybrid_mask":
            mask = getattr(attack, "mask", "") or ""
            wordlist_size = resources.get("wordlist_size", 0)
            custom_charsets = {
                "?1": getattr(attack, "custom_charset_1", "") or "",
                "?2": getattr(attack, "custom_charset_2", "") or "",
                "?3": getattr(attack, "custom_charset_3", "") or "",
                "?4": getattr(attack, "custom_charset_4", "") or "",
            }
            increment = getattr(attack, "increment_mode", False)
            min_len = getattr(attack, "increment_minimum", 0)
            max_len = getattr(attack, "increment_maximum", 0)
            mask_keyspace = int(
                AttackEstimationService._estimate_mask(
                    mask, custom_charsets, increment, min_len, max_len
                )
            )
            return int(mask_keyspace * wordlist_size)
        return 0

    @staticmethod
    def _estimate_mask(
        mask: str,
        custom_charsets: dict[str, str],
        increment: bool,
        min_len: int,
        max_len: int,
    ) -> int:
        charset_sizes = {
            "?l": 26,
            "?u": 26,
            "?d": 10,
            "?s": 33,
            "?a": 95,
            "?b": 256,
            "?h": 16,
            "?H": 16,
            "?D": 10,
            "?F": 16,
            "?C": 256,
        }
        for k, v in custom_charsets.items():
            if v:
                charset_sizes[k] = len(v)

        def mask_keyspace(m: str) -> int:
            tokens = re.findall(r"\?.", m)
            keyspace = 1
            for t in tokens:
                keyspace *= charset_sizes.get(t, 1)
            return int(keyspace)

        tokens = re.findall(r"\?.", mask)
        if increment and min_len and max_len and min_len < max_len:
            total = 0
            for length in range(min_len, max_len + 1):
                m = "".join(tokens[:length])
                total += int(mask_keyspace(m))
            return int(total)
        return int(mask_keyspace(mask))

    @staticmethod
    def calculate_complexity_from_keyspace(keyspace: int) -> int:
        # Example bucketing: 1-5 scale
        if keyspace < KEYSPACE_BUCKET_1:
            return 1
        if keyspace < KEYSPACE_BUCKET_2:
            return 2
        if keyspace < KEYSPACE_BUCKET_3:
            return 3
        if keyspace < KEYSPACE_BUCKET_4:
            return 4
        return 5

    @staticmethod
    def calculate_attack_complexity(
        attack: AttackCreate, resources: dict[str, Any]
    ) -> int:
        keyspace = AttackEstimationService.estimate_keyspace(attack, resources)
        return AttackEstimationService.calculate_complexity_from_keyspace(keyspace)


# Deprecated: for legacy compatibility only
# Use AttackEstimationService.calculate_attack_complexity instead


def calculate_attack_complexity(attack: Any) -> int:  # noqa: ANN401
    """
    Deprecated. Use AttackEstimationService.calculate_attack_complexity.
    This version is kept for legacy tests and expects a stub attack with dictionary_list, rule_list, mask_list.
    """
    # Dictionary + rule attack: Only if both lists are present (not None)
    if (
        getattr(attack, "dictionary_list", None) is not None
        and getattr(attack, "rule_list", None) is not None
    ):
        word_count = (
            getattr(getattr(attack, "dictionary_list", None), "word_count", 1) or 1
        )
        rule_count = getattr(getattr(attack, "rule_list", None), "rule_count", 1) or 1
        return max(1, word_count * rule_count)
    mask_list = getattr(attack, "mask_list", None)
    if mask_list and hasattr(mask_list, "masks") and mask_list.masks:
        total = 0
        for mask in mask_list.masks:
            keyspace = 1
            tokens = re.findall(r"\?\w", mask)
            for token in tokens:
                size = {
                    "?l": 26,
                    "?u": 26,
                    "?d": 10,
                    "?s": 33,
                    "?a": 95,
                }.get(token)
                if size:
                    keyspace *= size
            total += keyspace
        return max(1, total)
    return 1
