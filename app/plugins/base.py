from pathlib import Path

from app.models.raw_hash import RawHash
from app.schemas.shared import ParsedHashLine


def extract_hashes(path: Path) -> list[RawHash]:
    """
    Plugin interface: Extract hashes from the given file and return a list of RawHash ORM objects.
    Each plugin must implement this function for its supported file type.
    """
    raise NotImplementedError("extract_hashes() must be implemented by plugin.")


def parse_hash_line(raw_hash: RawHash) -> ParsedHashLine | None:
    """
    Plugin interface: Parse a RawHash into a ParsedHashLine, validating format and extracting fields.
    Each plugin must implement this function for its supported file type.
    """
    raise NotImplementedError("parse_hash_line() must be implemented by plugin.")
