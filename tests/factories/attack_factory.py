# type: ignore[assignment]
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.attack import Attack, AttackMode, AttackState, HashType


class AttackFactory(SQLAlchemyFactory[Attack]):
    __model__ = Attack
    name = "AttackTest"
    description = "A test attack"
    state = AttackState.PENDING
    hash_type = HashType.MD5
    attack_mode = AttackMode.DICTIONARY
    attack_mode_hashcat = 0
    hash_mode = 0
    mask = None
    increment_mode = False
    increment_minimum = 0
    increment_maximum = 0
    optimized = False
    slow_candidate_generators = False
    workload_profile = 3
    disable_markov = False
    classic_markov = False
    markov_threshold = 0
    left_rule = None
    right_rule = None
    custom_charset_1 = None
    custom_charset_2 = None
    custom_charset_3 = None
    custom_charset_4 = None
    hash_list_id = 1
    word_list_id = None
    rule_list_id = None
    mask_list_id = None
    hash_list_url = "http://example.com/hashes.txt"
    hash_list_checksum = "abc123"
    priority = 0
    campaign_id = None
    template_id = None
