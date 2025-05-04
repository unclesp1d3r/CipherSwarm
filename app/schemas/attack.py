from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, Field

from app.models.attack import AttackMode, AttackState


class AttackBase(BaseModel):
    name: Annotated[str, Field(max_length=128)]
    description: Annotated[str | None, Field(max_length=1024)] = None
    state: AttackState = AttackState.PENDING
    hash_type_id: int
    attack_mode: AttackMode
    attack_mode_hashcat: int = 0
    hash_mode: int = 0
    mask: str | None = None
    increment_mode: bool = False
    increment_minimum: int = 0
    increment_maximum: int = 0
    optimized: bool = False
    slow_candidate_generators: bool = False
    workload_profile: int = 3
    disable_markov: bool = False
    classic_markov: bool = False
    markov_threshold: int = 0
    left_rule: str | None = None
    right_rule: str | None = None
    custom_charset_1: str | None = None
    custom_charset_2: str | None = None
    custom_charset_3: str | None = None
    custom_charset_4: str | None = None
    hash_list_id: int
    hash_list_url: str
    hash_list_checksum: str
    priority: int = 0
    start_time: datetime | None = None
    end_time: datetime | None = None
    campaign_id: int | None = None
    template_id: int | None = None


class AttackCreate(AttackBase):
    pass


class AttackUpdate(BaseModel):
    name: Annotated[str | None, Field(max_length=128)] = None
    description: Annotated[str | None, Field(max_length=1024)] = None
    state: AttackState | None = None
    hash_type_id: int | None = None
    attack_mode: AttackMode | None = None
    attack_mode_hashcat: int | None = None
    hash_mode: int | None = None
    mask: str | None = None
    increment_mode: bool | None = None
    increment_minimum: int | None = None
    increment_maximum: int | None = None
    optimized: bool | None = None
    slow_candidate_generators: bool | None = None
    workload_profile: int | None = None
    disable_markov: bool | None = None
    classic_markov: bool | None = None
    markov_threshold: int | None = None
    left_rule: str | None = None
    right_rule: str | None = None
    custom_charset_1: str | None = None
    custom_charset_2: str | None = None
    custom_charset_3: str | None = None
    custom_charset_4: str | None = None
    hash_list_id: int | None = None
    word_list_id: int | None = None
    rule_list_id: int | None = None
    mask_list_id: int | None = None
    hash_list_url: str | None = None
    hash_list_checksum: str | None = None
    priority: int | None = None
    start_time: datetime | None = None
    end_time: datetime | None = None
    campaign_id: int | None = None
    template_id: int | None = None


class AttackOut(BaseModel):
    id: int
    name: str
    description: str | None
    state: AttackState
    hash_type_id: int
    attack_mode: AttackMode
    attack_mode_hashcat: int
    hash_mode: int
    mask: str | None
    increment_mode: bool
    increment_minimum: int
    increment_maximum: int
    optimized: bool
    slow_candidate_generators: bool
    workload_profile: int
    disable_markov: bool
    classic_markov: bool
    markov_threshold: int
    left_rule: str | None
    right_rule: str | None
    custom_charset_1: str | None
    custom_charset_2: str | None
    custom_charset_3: str | None
    custom_charset_4: str | None
    hash_list_id: int
    word_list_id: int | None = None
    rule_list_id: int | None = None
    mask_list_id: int | None = None
    hash_list_url: str
    hash_list_checksum: str
    priority: int
    start_time: datetime | None
    end_time: datetime | None
    campaign_id: int | None
    template_id: int | None

    model_config = {"from_attributes": True}
