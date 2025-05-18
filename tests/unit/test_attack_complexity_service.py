from typing import Any, Literal

import pytest

from app.core.services.attack_complexity_service import (
    AttackEstimationService,
    calculate_attack_complexity,
)


class StubDict:
    def __init__(
        self,
        *,
        word_count: int | None = None,
        rule_count: int | None = None,
        masks: Any = None,
    ) -> None:
        self.word_count: int | None = word_count
        self.rule_count: int | None = rule_count
        self.masks = masks


class StubAttack:
    def __init__(
        self,
        *,
        dictionary_list: Any = None,
        rule_list: Any = None,
        mask_list: Any = None,
    ) -> None:
        self.dictionary_list = dictionary_list
        self.rule_list = rule_list
        self.mask_list = mask_list


@pytest.mark.parametrize(
    ("word_count", "rule_count", "expected"),
    [
        (100, 5, 500),
        (5000, 0, 5000),
        (100, None, 100),
    ],
)
def test_dictionary_attack(
    word_count: Literal[100, 5000],
    rule_count: Literal[5, 0] | None,
    expected: Literal[500, 5000, 100],
) -> None:
    attack = StubAttack(
        dictionary_list=StubDict(word_count=word_count),
        rule_list=StubDict(rule_count=rule_count),
    )
    assert calculate_attack_complexity(attack) == expected


def test_mask_attack_simple() -> None:
    # ?l?l?l = 26*26*26 = 17576
    mask_list = StubDict(masks=["?l?l?l"])
    attack = StubAttack(mask_list=mask_list)
    assert calculate_attack_complexity(attack) == 17576  # noqa: PLR2004


def test_mask_attack_multiple() -> None:
    # ?d?d = 10*10 = 100, ?u?u = 26*26 = 676, total = 776
    mask_list = StubDict(masks=["?d?d", "?u?u"])
    attack = StubAttack(mask_list=mask_list)
    assert calculate_attack_complexity(attack) == 776  # noqa: PLR2004


def test_mask_attack_unsupported_token() -> None:
    # ?z?z = 1*1 = 1
    mask_list = StubDict(masks=["?z?z"])
    attack = StubAttack(mask_list=mask_list)
    assert calculate_attack_complexity(attack) == 1


def test_mask_attack_empty() -> None:
    mask_list = StubDict(masks=[])
    attack = StubAttack(mask_list=mask_list)
    assert calculate_attack_complexity(attack) == 1


def test_fallback_no_data() -> None:
    attack = StubAttack()
    assert calculate_attack_complexity(attack) == 1


def test_generate_brute_force_mask_and_charset_basic() -> None:
    result = AttackEstimationService.generate_brute_force_mask_and_charset(
        ["lowercase", "numbers"], 5
    )
    assert result["mask"] == "?1?1?1?1?1"
    assert result["custom_charset"] == "?1=?l?d"


def test_generate_brute_force_mask_and_charset_empty() -> None:
    result = AttackEstimationService.generate_brute_force_mask_and_charset([], 5)
    assert result["mask"] == ""
    assert result["custom_charset"] == ""


def test_generate_brute_force_mask_and_charset_zero_length() -> None:
    result = AttackEstimationService.generate_brute_force_mask_and_charset(
        ["lowercase"], 0
    )
    assert result["mask"] == ""
    assert result["custom_charset"] == ""


def test_generate_brute_force_mask_and_charset_all_charsets() -> None:
    result = AttackEstimationService.generate_brute_force_mask_and_charset(
        ["lowercase", "uppercase", "numbers", "symbols", "space"], 3
    )
    assert result["mask"] == "?1?1?1"
    # Should use tokens for all standard charsets
    assert result["custom_charset"] == "?1=?l?u?d?s?s"
