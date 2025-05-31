from pathlib import Path

from app.models.raw_hash import RawHash
from app.schemas.shared import ParsedHashLine


def extract_hashes(path: Path) -> list[RawHash]:
    """
    Plugin interface: Extract hashes from the given file and return a list of RawHash ORM objects.
    Each plugin must implement this function for its supported file type.

    Args:
        path: Path to the file to extract hashes from

    Returns:
        List of RawHash objects

    Raises:
        ValueError: If the file is not supported by the plugin

    Note:
        The primary purpose is to take the original file and extract any recoverable hashes from it, with as much fidelity as possible.
        It is not necessary that the hashes be in hashcat format, but they should be in a format that contains enough information to be useful and can be parsed by the `parse_hash_line` function.
    """
    raise NotImplementedError("extract_hashes() must be implemented by plugin.")


def parse_hash_line(raw_hash: RawHash) -> ParsedHashLine | None:
    """
    Plugin interface: Parse a RawHash into a ParsedHashLine, validating format and extracting fields.
    Each plugin must implement this function for its supported file type.

    Args:
        raw_hash: RawHash object to parse

    Returns:
        ParsedHashLine object if parsing is successful, None otherwise

    Raises:
        ValueError: If the hash is not valid for the plugin

    Note:
        The primary purpose is to take a `RawHash` object and extract the necessary fields to produce a valid hashcat hash, as well as any additional metadata.
        The `RawHash` object is not guaranteed to have a `username` or `meta` field, so the plugin should handle these cases gracefully.
    """
    raise NotImplementedError("parse_hash_line() must be implemented by plugin.")
