from datetime import datetime
from enum import Enum
from uuid import UUID

from sqlalchemy import Boolean, ForeignKey, Integer, String
from sqlalchemy import Enum as SQLAEnum
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class AttackMode(str, Enum):
    """Enum for attack modes."""

    DICTIONARY = "dictionary"
    MASK = "mask"
    HYBRID_DICTIONARY = "hybrid_dictionary"
    HYBRID_MASK = "hybrid_mask"


class AttackState(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    ABANDONED = "abandoned"


class HashType(str, Enum):
    MD5 = "md5"
    SHA1 = "sha1"
    SHA256 = "sha256"
    NTLM = "ntlm"
    # Add more as needed


class Attack(Base):
    """Model for password cracking attacks."""

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)

    # Basic attack configuration
    attack_mode: Mapped[AttackMode] = mapped_column(
        SQLAEnum(AttackMode), default=AttackMode.DICTIONARY, nullable=False
    )
    attack_mode_hashcat: Mapped[int] = mapped_column(Integer, default=0)
    hash_mode: Mapped[int] = mapped_column(Integer, default=0)

    # Attack parameters
    mask: Mapped[str | None] = mapped_column(String(255), nullable=True)
    increment_mode: Mapped[bool] = mapped_column(Boolean, default=False)
    increment_minimum: Mapped[int] = mapped_column(Integer, default=0)
    increment_maximum: Mapped[int] = mapped_column(Integer, default=0)
    optimized: Mapped[bool] = mapped_column(Boolean, default=False)
    slow_candidate_generators: Mapped[bool] = mapped_column(Boolean, default=False)
    workload_profile: Mapped[int] = mapped_column(Integer, default=3)

    # Markov configuration
    disable_markov: Mapped[bool] = mapped_column(Boolean, default=False)
    classic_markov: Mapped[bool] = mapped_column(Boolean, default=False)
    markov_threshold: Mapped[int] = mapped_column(Integer, default=0)

    # Rule configuration
    left_rule: Mapped[str | None] = mapped_column(String(255), nullable=True)
    right_rule: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Custom charsets
    custom_charset_1: Mapped[str | None] = mapped_column(String(255), nullable=True)
    custom_charset_2: Mapped[str | None] = mapped_column(String(255), nullable=True)
    custom_charset_3: Mapped[str | None] = mapped_column(String(255), nullable=True)
    custom_charset_4: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Resource references
    hash_list_id: Mapped[int] = mapped_column(Integer, nullable=False)
    # word_list_id: Mapped[int | None] = mapped_column(
    #     Integer, ForeignKey("attackresourcefiles.id"), nullable=True
    # )  # TODO: Phase 3 - resource management
    # rule_list_id: Mapped[int | None] = mapped_column(
    #     Integer, ForeignKey("attackresourcefiles.id"), nullable=True
    # )  # TODO: Phase 3 - resource management
    # mask_list_id: Mapped[int | None] = mapped_column(
    #     Integer, ForeignKey("attackresourcefiles.id"), nullable=True
    # )  # TODO: Phase 3 - resource management

    # URLs and checksums
    hash_list_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    hash_list_checksum: Mapped[str] = mapped_column(String(64), nullable=False)

    # Additional fields
    name: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    state: Mapped[AttackState] = mapped_column(
        SQLAEnum(AttackState), default=AttackState.PENDING, nullable=False, index=True
    )
    hash_type: Mapped[HashType] = mapped_column(SQLAEnum(HashType), nullable=False)
    priority: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    start_time: Mapped[datetime | None] = mapped_column(nullable=True)
    end_time: Mapped[datetime | None] = mapped_column(nullable=True)
    campaign_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("projects.id"), nullable=True, index=True
    )
    template_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("attacks.id"), nullable=True
    )

    # Relationships
    # word_list = relationship(
    #     "AttackResourceFile",
    #     foreign_keys=[word_list_id],
    #     back_populates="word_list_attacks",
    # )  # TODO: Phase 3 - resource management
    # rule_list = relationship(
    #     "AttackResourceFile",
    #     foreign_keys=[rule_list_id],
    #     back_populates="rule_list_attacks",
    # )  # TODO: Phase 3 - resource management
    # mask_list = relationship(
    #     "AttackResourceFile",
    #     foreign_keys=[mask_list_id],
    #     back_populates="mask_list_attacks",
    # )  # TODO: Phase 3 - resource management
    tasks = relationship("Task", back_populates="attack")
    campaign = relationship("Project", back_populates="attacks")
    template = relationship("Attack", remote_side="Attack.id", backref="clones")
