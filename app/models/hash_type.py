from sqlalchemy import Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class HashType(Base):
    """Model for supported hash types (hashcat modes).

    Fields:
        - id (int): The ID of the hash type.
        - name (str): The name of the hash type.
        - description (str | None): The description of the hash type.
        - john_mode (int | None): The John the Ripper mode of the hash type.
    """

    id: Mapped[int] = mapped_column(
        Integer, primary_key=True
    )  # This is the hashcat mode
    name: Mapped[str] = mapped_column(String(64), unique=True, nullable=False)
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    john_mode: Mapped[int | None] = mapped_column(String(32), nullable=True)
