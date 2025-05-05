# type: ignore
import pytest

from app.core.services.attack_complexity_service import calculate_attack_complexity


class StubDict:
    def __init__(self, word_count=None, rule_count=None, masks=None):
        self.word_count = word_count
        self.rule_count = rule_count
        self.masks = masks


class StubAttack:
    def __init__(self, dictionary_list=None, rule_list=None, mask_list=None):
        self.dictionary_list = dictionary_list
        self.rule_list = rule_list
        self.mask_list = mask_list


@pytest.mark.parametrize(
    "word_count,rule_count,expected",
    [
        (100, 5, 500),
        (5000, 0, 5000),
        (100, None, 100),
    ],
)
def test_dictionary_attack(word_count, rule_count, expected):
    attack = StubAttack(
        dictionary_list=StubDict(word_count=word_count),
        rule_list=StubDict(rule_count=rule_count),
    )
    assert calculate_attack_complexity(attack) == expected  # type: ignore


def test_mask_attack_simple():
    # ?l?l?l = 26*26*26 = 17576
    mask_list = StubDict(masks=["?l?l?l"])
    attack = StubAttack(mask_list=mask_list)
    assert calculate_attack_complexity(attack) == 17576  # type: ignore


def test_mask_attack_multiple():
    # ?d?d = 10*10 = 100, ?u?u = 26*26 = 676, total = 776
    mask_list = StubDict(masks=["?d?d", "?u?u"])
    attack = StubAttack(mask_list=mask_list)
    assert calculate_attack_complexity(attack) == 776  # type: ignore


def test_mask_attack_unsupported_token():
    # ?z?z = 1*1 = 1
    mask_list = StubDict(masks=["?z?z"])
    attack = StubAttack(mask_list=mask_list)
    assert calculate_attack_complexity(attack) == 1  # type: ignore


def test_mask_attack_empty():
    mask_list = StubDict(masks=[])
    attack = StubAttack(mask_list=mask_list)
    assert calculate_attack_complexity(attack) == 1  # type: ignore


def test_fallback_no_data():
    attack = StubAttack()
    assert calculate_attack_complexity(attack) == 1  # type: ignore
