import re
from typing import TYPE_CHECKING

from loguru import logger

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
    # Dictionary + rule attack: Only if both lists are present (not None)
    if (
        getattr(attack, "dictionary_list", None) is not None
        and getattr(attack, "rule_list", None) is not None
    ):
        logger.debug("Calculating complexity for dictionary+rule attack")
        word_count = (
            getattr(getattr(attack, "dictionary_list", None), "word_count", 1) or 1
        )
        rule_count = getattr(getattr(attack, "rule_list", None), "rule_count", 1) or 1
        return max(1, word_count * rule_count)
    # Mask attack: Only if mask_list is present and has masks
    mask_list = getattr(attack, "mask_list", None)
    if mask_list and hasattr(mask_list, "masks") and mask_list.masks:
        logger.debug("Calculating complexity for mask attack")
        total = 0
        for mask in mask_list.masks:
            keyspace = 1
            tokens = re.findall(r"\?\w", mask)
            for token in tokens:
                size = TOKEN_SIZES.get(token)
                if size:
                    keyspace *= size
            total += keyspace
        return max(1, total)
    # Fallback: complexity 1 (no valid attack config)
    logger.debug("Fallback: unknown or empty attack config, returning complexity 1")
    return 1
