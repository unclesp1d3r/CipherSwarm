from sqlalchemy import JSON, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class HashItem(Base):
    """Model for an individual hash in a hash list.

    Fields:
        - id (int): The ID of the hash item.
        - hash (str): The hash value.
        - salt (str | None): The salt value, if present.
        - meta (dict[str, str] | None): Metadata for the hash item.
        - plain_text (str | None): The cracked plain text, if available.
        - hash_lists (list[HashList]): The hash lists that the hash item belongs to.

    Notes:
        - The `meta` field is a JSON column that stores user-defined metadata for the hash item. It is a dictionary of strings.
        - The `plain_text` field is a string column that stores the cracked plain text, if available. A hash is considered cracked if it has a non-null plain_text.
        - The `hash_lists` field is a many-to-many relationship to the `HashList` model. A hash item should always be unique within the system, based on `hash`, `meta`, and `salt` values, but can be associated with multiple hash lists.
        - The `hash` and `salt` fields are unique together, and the combination of `hash`, `meta`, and `salt` must be unique.
        - The `hash` field is a string column that stores the hash value in hexadecimal format. It is required.
        - The `salt` field is a string column that stores the salt value, if present. It is optional.
    """

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    hash: Mapped[str] = mapped_column(String(512), nullable=False)
    salt: Mapped[str | None] = mapped_column(String(512), nullable=True)
    meta: Mapped[dict[str, str] | None] = mapped_column(JSON, nullable=True)
    # Legacy contract: cracked hashes are those with non-null plain_text (see legacy hash_item.rb)
    plain_text: Mapped[str | None] = mapped_column(String(512), nullable=True)
    # Many-to-many relationship to HashList
    hash_lists = relationship(
        "HashList", secondary="hash_list_items", back_populates="items"
    )
    # created_at and updated_at are inherited from Base
    __table_args__ = (UniqueConstraint("hash", "salt", name="uq_hashitem_hash_salt"),)
