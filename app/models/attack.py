from enum import Enum
from typing import Optional

from sqlalchemy import String, Integer, Boolean, ForeignKey, Enum as SQLAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class AttackMode(str, Enum):
    """Enum for attack modes."""

    DICTIONARY = "dictionary"
    MASK = "mask"
    HYBRID_DICTIONARY = "hybrid_dictionary"
    HYBRID_MASK = "hybrid_mask"


class Attack(Base):
    """Model for password cracking attacks."""

    # Basic attack configuration
    attack_mode: Mapped[AttackMode] = mapped_column(
        SQLAEnum(AttackMode), default=AttackMode.DICTIONARY, nullable=False
    )
    attack_mode_hashcat: Mapped[int] = mapped_column(Integer, default=0)
    hash_mode: Mapped[int] = mapped_column(Integer, default=0)

    # Attack parameters
    mask: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
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
    left_rule: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    right_rule: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Custom charsets
    custom_charset_1: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    custom_charset_2: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    custom_charset_3: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    custom_charset_4: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Resource references
    hash_list_id: Mapped[int] = mapped_column(Integer, nullable=False)
    word_list_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("attackresourcefiles.id"), nullable=True
    )
    rule_list_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("attackresourcefiles.id"), nullable=True
    )
    mask_list_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("attackresourcefiles.id"), nullable=True
    )

    # URLs and checksums
    hash_list_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    hash_list_checksum: Mapped[str] = mapped_column(String(64), nullable=False)

    # Relationships
    word_list = relationship(
        "AttackResourceFile",
        foreign_keys=[word_list_id],
        back_populates="word_list_attacks",
    )
    rule_list = relationship(
        "AttackResourceFile",
        foreign_keys=[rule_list_id],
        back_populates="rule_list_attacks",
    )
    mask_list = relationship(
        "AttackResourceFile",
        foreign_keys=[mask_list_id],
        back_populates="mask_list_attacks",
    )
    tasks = relationship("Task", back_populates="attack")
