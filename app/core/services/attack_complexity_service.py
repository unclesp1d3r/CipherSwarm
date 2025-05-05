from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from app.models.attack import Attack

TOKEN_SIZES = {
    "?l": 26,  # lowercase
    "?u": 26,  # uppercase
    "?d": 10,  # digits
    "?s": 33,  # symbols
    "?a": 95,  # all printable
}


def calculate_attack_complexity(attack: "Attack") -> int:
    # Dictionary + rule attack
    if hasattr(attack, "dictionary_list") and hasattr(attack, "rule_list"):
        word_count = (
            getattr(getattr(attack, "dictionary_list", None), "word_count", 1) or 1
        )
        rule_count = getattr(getattr(attack, "rule_list", None), "rule_count", 1) or 1
        return max(1, word_count * rule_count)
    # Mask attack
    mask_list = getattr(attack, "mask_list", None)
    if mask_list and hasattr(mask_list, "masks"):
        total = 0
        for mask in mask_list.masks:
            keyspace = 1
            i = 0
            while i < len(mask):
                if mask[i] == "?" and i + 1 < len(mask):
                    token = mask[i : i + 2]
                    size = TOKEN_SIZES.get(token, 1)
                    keyspace *= size
                    i += 2
                else:
                    i += 1
            total += keyspace
        return max(1, total)
    # Fallback: complexity 1
    return 1
