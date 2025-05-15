from datetime import datetime
from enum import Enum
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.attack import AttackMode, AttackState
from app.models.attack_resource_file import AttackResourceType


class AttackResourceFileOut(BaseModel):
    id: int
    download_url: str
    checksum: str
    file_name: str
    guid: UUID
    resource_type: Annotated[
        AttackResourceType, Field(description="Type of resource file")
    ]
    line_format: Annotated[
        str, Field(description="Format of each line in the resource file")
    ]
    line_encoding: Annotated[
        str, Field(description="Encoding of the resource file lines")
    ]
    used_for_modes: Annotated[
        list[AttackMode],
        Field(description="Attack modes this resource is compatible with"),
    ]
    source: Annotated[
        str,
        Field(description="Source of the resource file (upload, generated, linked)"),
    ]
    line_count: Annotated[
        int, Field(description="Number of lines in the resource file")
    ]
    byte_size: Annotated[int, Field(description="Size of the resource file in bytes")]

    model_config = ConfigDict(from_attributes=True)


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
    position: int = 0
    start_time: datetime | None = None
    end_time: datetime | None = None
    campaign_id: int | None = None
    template_id: int | None = None


class AttackCreate(AttackBase):
    masks_inline: list[str] | None = None  # Ephemeral mask list lines


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
    position: int | None = None
    start_time: datetime | None = None
    end_time: datetime | None = None
    campaign_id: int | None = None
    template_id: int | None = None
    masks_inline: list[str] | None = None  # Ephemeral mask list lines
    confirm: bool | None = None  # Required for edit confirmation flow


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
    word_list: AttackResourceFileOut | None = None
    rule_list: AttackResourceFileOut | None = None
    mask_list: AttackResourceFileOut | None = None
    hash_list_url: str
    hash_list_checksum: str
    priority: int
    position: int
    start_time: datetime | None
    end_time: datetime | None
    campaign_id: int | None
    template_id: int | None

    model_config = ConfigDict(from_attributes=True)


class AttackOutV1(BaseModel):
    id: Annotated[int, Field(..., description="The id of the attack")]
    attack_mode: Annotated[
        str, Field(..., description="Attack mode name")
    ]  # must be str for OpenAPI enum
    attack_mode_hashcat: Annotated[int, Field(..., description="hashcat attack mode")]
    mask: Annotated[
        str | None, Field(default=None, description="A hashcat mask string")
    ]
    increment_mode: Annotated[
        bool, Field(..., description="Enable hashcat increment mode")
    ]
    increment_minimum: Annotated[
        int, Field(..., description="The start of the increment range")
    ]
    increment_maximum: Annotated[
        int, Field(..., description="The end of the increment range")
    ]
    optimized: Annotated[bool, Field(..., description="Enable hashcat optimized mode")]
    slow_candidate_generators: Annotated[
        bool, Field(..., description="Enable hashcat slow candidate generators")
    ]
    workload_profile: Annotated[
        int, Field(..., description="The hashcat workload profile")
    ]
    disable_markov: Annotated[
        bool, Field(..., description="Disable hashcat markov mode")
    ]
    classic_markov: Annotated[
        bool, Field(..., description="Enable hashcat classic markov mode")
    ]
    markov_threshold: Annotated[
        int, Field(..., description="The hashcat markov threshold")
    ]
    left_rule: Annotated[
        str | None,
        Field(default=None, description="The left-hand rule for combinator attacks"),
    ]
    right_rule: Annotated[
        str | None,
        Field(default=None, description="The right-hand rule for combinator attacks"),
    ]
    custom_charset_1: Annotated[
        str | None,
        Field(default=None, description="Custom charset 1 for hashcat mask attacks"),
    ]
    custom_charset_2: Annotated[
        str | None,
        Field(default=None, description="Custom charset 2 for hashcat mask attacks"),
    ]
    custom_charset_3: Annotated[
        str | None,
        Field(default=None, description="Custom charset 3 for hashcat mask attacks"),
    ]
    custom_charset_4: Annotated[
        str | None,
        Field(default=None, description="Custom charset 4 for hashcat mask attacks"),
    ]
    hash_list_id: Annotated[int, Field(..., description="The id of the hash list")]
    word_list: Annotated[
        AttackResourceFileOut | None,
        Field(default=None, description="Word list resource file"),
    ]
    rule_list: Annotated[
        AttackResourceFileOut | None,
        Field(default=None, description="Rule list resource file"),
    ]
    mask_list: Annotated[
        AttackResourceFileOut | None,
        Field(default=None, description="Mask list resource file"),
    ]
    hash_mode: Annotated[int, Field(..., description="The hashcat hash mode")]
    hash_list_url: Annotated[
        str | None,
        Field(default=None, description="The download URL for the hash list"),
    ]
    hash_list_checksum: Annotated[
        str | None, Field(default=None, description="The MD5 checksum of the hash list")
    ]
    url: Annotated[str | None, Field(default=None, description="The URL to the attack")]

    model_config = ConfigDict(extra="ignore", from_attributes=True)


class AttackMoveDirection(str, Enum):
    UP = "up"
    DOWN = "down"
    TOP = "top"
    BOTTOM = "bottom"


class AttackMoveRequest(BaseModel):
    direction: Annotated[
        AttackMoveDirection, Field(..., description="Direction to move the attack")
    ]


class AttackBulkDeleteRequest(BaseModel):
    attack_ids: Annotated[
        list[int], Field(..., description="List of attack IDs to delete")
    ]


class AttackSummary(BaseModel):
    id: int
    name: str
    attack_mode: AttackMode
    type_label: str
    length: int | None = None
    settings_summary: str
    keyspace: int | None = None
    complexity_score: int | None = None
    comment: str | None = None

    model_config = ConfigDict(from_attributes=True)


class BruteForceMaskRequest(BaseModel):
    charset_options: Annotated[
        list[str],
        Field(description="List of charset options, e.g. ['lowercase', 'numbers']"),
    ]
    length: Annotated[int, Field(description="Length of the mask to generate")]


class AttackResourceEstimationContext(BaseModel):
    wordlist_size: Annotated[
        int, Field(10000, description="Number of words in the wordlist")
    ]
    rule_count: Annotated[int, Field(1, description="Number of rules applied")]
    # Add more fields as needed for future estimation logic


class EstimateAttackRequest(BaseModel):
    """
    Request model for attack keyspace/complexity estimation.
    Accepts partial or full attack config fields for unsaved attacks.
    """

    name: Annotated[
        str | None,
        Field(default=None, description="Attack name", examples=["Test Attack"]),
    ]
    description: Annotated[
        str | None,
        Field(default=None, description="Attack description", examples=["Test"]),
    ]
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
    hash_list_url: str | None = None
    hash_list_checksum: str | None = None
    priority: int | None = None
    position: int | None = None
    start_time: datetime | None = None
    end_time: datetime | None = None
    campaign_id: int | None = None
    template_id: int | None = None
    wordlist_size: int | None = None
    rule_count: int | None = None


class EstimateAttackResponse(BaseModel):
    keyspace: Annotated[
        int, Field(description="Estimated keyspace", examples=[1000000])
    ]
    complexity_score: Annotated[
        int, Field(description="Complexity score (1-5)", examples=[3])
    ]
