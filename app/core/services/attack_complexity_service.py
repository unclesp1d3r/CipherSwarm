import re
from typing import Any

from typing_extensions import deprecated  # noqa: UP035

from app.schemas.attack import AttackCreate, AttackResourceEstimationContext

TOKEN_SIZES: dict[str, int] = {
    "?l": 26,  # lowercase
    "?u": 26,  # uppercase
    "?d": 10,  # digits
    "?s": 33,  # symbols
    "?a": 95,  # all printable
    "?b": 256,  # byte
    "?h": 16,  # hex lower
    "?H": 16,  # hex upper
    "?D": 10,  # digit
    "?F": 16,  # hex
    "?C": 256,  # byte
}

# Keyspace bucket thresholds for complexity scoring
KEYSPACE_BUCKET_1 = 1_000_000
KEYSPACE_BUCKET_2 = 100_000_000
KEYSPACE_BUCKET_3 = 10_000_000_000
KEYSPACE_BUCKET_4 = 1_000_000_000_000

CHARSET_MAP = {
    "lowercase": "abcdefghijklmnopqrstuvwxyz",
    "uppercase": "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
    "numbers": "0123456789",
    "symbols": "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~",
    "space": " ",
}


class AttackEstimationService:
    """
    Service for estimating attack keyspace and complexity.
    """

    @staticmethod
    def estimate_keyspace(
        attack: AttackCreate, resources: AttackResourceEstimationContext
    ) -> int:
        """
        Estimate the total keyspace for an attack configuration.
        The keyspace is the total number of candidate passwords that will be tried.
        This method dispatches to the correct calculation based on attack_mode.
        """
        mode = getattr(attack, "attack_mode", None)
        if mode == "dictionary":
            # Dictionary mode: keyspace = wordlist size * rule count
            return int(resources.wordlist_size * resources.rule_count)
        if mode == "mask":
            # Mask mode: keyspace is determined by the mask pattern and charsets
            mask = getattr(attack, "mask", "")
            custom_charsets = {
                f"?{i}": getattr(attack, f"custom_charset_{i}", "") for i in range(1, 5)
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
            # Hybrid dictionary: wordlist applied to each mask candidate
            wordlist_size = resources.wordlist_size
            mask = getattr(attack, "mask", "")
            custom_charsets = {
                f"?{i}": getattr(attack, f"custom_charset_{i}", "") for i in range(1, 5)
            }
            increment = getattr(attack, "increment_mode", False)
            min_len = getattr(attack, "increment_minimum", 0)
            max_len = getattr(attack, "increment_maximum", 0)
            mask_keyspace = AttackEstimationService._estimate_mask(
                mask, custom_charsets, increment, min_len, max_len
            )
            return int(wordlist_size * mask_keyspace)
        if mode == "hybrid_mask":
            # Hybrid mask: mask applied to each wordlist candidate
            mask = getattr(attack, "mask", "")
            wordlist_size = resources.wordlist_size
            custom_charsets = {
                f"?{i}": getattr(attack, f"custom_charset_{i}", "") for i in range(1, 5)
            }
            increment = getattr(attack, "increment_mode", False)
            min_len = getattr(attack, "increment_minimum", 0)
            max_len = getattr(attack, "increment_maximum", 0)
            mask_keyspace = AttackEstimationService._estimate_mask(
                mask, custom_charsets, increment, min_len, max_len
            )
            return int(mask_keyspace * wordlist_size)
        # Unknown or unsupported mode
        return 0

    @staticmethod
    def _estimate_mask(
        mask: str,
        custom_charsets: dict[str, str],
        increment: bool,
        min_len: int,
        max_len: int,
    ) -> int:
        """
        Estimate the keyspace for a mask attack.
        - Supports custom charsets (?1, ?2, ?3, ?4) and standard tokens.
        - If increment mode is enabled, sums keyspaces for all lengths in [min_len, max_len].
        - Otherwise, computes keyspace for the mask as given.
        """
        # Start with the standard charset sizes, then override with any custom charsets
        charset_sizes = TOKEN_SIZES.copy()
        for k, v in custom_charsets.items():
            if v:
                charset_sizes[k] = len(v)

        def mask_keyspace(m: str) -> int:
            # Compute the keyspace for a single mask string
            tokens = re.findall(r"\?.", m)  # find all tokens in the mask
            keyspace = 1
            for t in tokens:
                keyspace *= charset_sizes.get(t, 1)
            return keyspace

        tokens = re.findall(r"\?.", mask)  # find all tokens in the mask
        if increment and min_len and max_len and min_len < max_len:
            # Increment mode: sum keyspaces for all mask lengths in range
            return sum(
                mask_keyspace("".join(tokens[:length]))
                for length in range(min_len, max_len + 1)
            )
        # Standard mode: compute keyspace for the full mask
        return mask_keyspace(mask)

    @staticmethod
    def calculate_complexity_from_keyspace(keyspace: int) -> int:
        """
        Map a keyspace value to a complexity bucket (1-5).
        Buckets are defined by project-wide constants.
        """
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
        attack: AttackCreate, resources: AttackResourceEstimationContext
    ) -> int:
        """
        Calculate attack complexity (1-5) for a given attack and resources.
        This is the main entry point for scoring attack difficulty.
        """
        keyspace = AttackEstimationService.estimate_keyspace(attack, resources)
        return AttackEstimationService.calculate_complexity_from_keyspace(keyspace)

    @staticmethod
    def generate_brute_force_mask_and_charset(
        charset_options: list[str],
        length: int,
    ) -> dict[str, str]:
        """
        Given a list of charset options and a length, generate the mask and custom charset string for brute force UI.
        If the selected charsets map directly to hashcat tokens, use the token string (e.g., '?l?d') in the custom_charset.
        Otherwise, fall back to the expanded character set.
        Example: ['lowercase', 'numbers'], 5 -> {'mask': '?1?1?1?1?1', 'custom_charset': '?1=?l?d'}
        """
        if not charset_options or length < 1:
            return {"mask": "", "custom_charset": ""}
        # Map charset options to hashcat tokens if possible
        token_map = {
            "lowercase": "?l",
            "uppercase": "?u",
            "numbers": "?d",
            "symbols": "?s",
            "space": "?s",  # hashcat does not have a separate token for space, but ?s includes space
        }
        tokens = [token_map[c] for c in charset_options if c in token_map]
        if tokens:
            custom_charset = f"?1={''.join(tokens)}"
        else:
            charset = "".join(
                CHARSET_MAP[c] for c in charset_options if c in CHARSET_MAP
            )
            # Deduplicate characters while preserving order
            seen = set()
            deduped_charset = []
            for ch in charset:
                if ch not in seen:
                    seen.add(ch)
                    deduped_charset.append(ch)
            charset = "".join(deduped_charset)
            custom_charset = f"?1={charset}"
        mask = "?1" * length
        return {"mask": mask, "custom_charset": custom_charset}


@deprecated("Use AttackEstimationService.calculate_attack_complexity instead")
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
