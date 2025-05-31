from pathlib import Path

from app.models.raw_hash import RawHash


def extract_hashes(path: Path) -> list[RawHash]:
    """
    Plugin interface: Extract hashes from the given file and return a list of RawHash ORM objects.
    Each plugin must implement this function for its supported file type.
    """
    raise NotImplementedError("extract_hashes() must be implemented by plugin.")
