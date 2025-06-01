import re
from pathlib import Path

from app.core.logging import logger
from app.core.services.hash_guess_service import HashGuessService
from app.models.raw_hash import RawHash
from app.schemas.shared import HashGuessCandidate, ParsedHashLine

shadow_regex = re.compile(r"^(?P<username>[^:]+):(?P<hash>[^:]+):.*$")


def extract_hashes(path: Path, upload_task_id: int = 1) -> list[RawHash]:
    """
    Extract hashes from a Linux shadow or unshadowed file.
    Returns a list of RawHash objects (not yet committed to DB).
    """
    raw_hashes = []
    lines = []
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for idx, raw_line in enumerate(f, 1):
            line = raw_line.strip()
            lines.append(line)
            logger.debug(f"[extract_hashes] Line {idx}: {line}")
            if not line or line.startswith("#"):
                continue
            m = shadow_regex.match(line)
            logger.debug(f"[extract_hashes] Line {idx}: {line}")
            if m:
                logger.debug(
                    f"[extract_hashes] Extracted username: {m.group('username')}, hash: {m.group('hash')}"
                )
            if not m:
                continue  # skip lines that don't match
            username = m.group("username")
            hashval = m.group("hash")
            # Guess hash type (default to 1800/sha512crypt if not found)
            guess: list[HashGuessCandidate] = HashGuessService.guess_hash_types(
                hashval, limit=1
            )
            hash_type_id = 1800  # default to sha512crypt
            if guess:
                hash_type_id = guess[
                    0
                ].hash_type  # TODO: We should be using the confidence score to determine the hash type
            raw_hashes.append(
                RawHash(
                    hash=hashval,
                    hash_type_id=hash_type_id,
                    username=username,
                    meta=None,
                    line_number=idx,
                    upload_error_entry_id=None,
                    upload_task_id=upload_task_id,
                )
            )
    if not raw_hashes:
        logger.warning(f"No matches found in extract_hashes. Lines read: {lines}")
    return raw_hashes


def parse_hash_line(
    raw_hash: RawHash, confidence_threshold: float = 0.7
) -> ParsedHashLine | None:
    """
    Parse a RawHash into a ParsedHashLine, validating format and hash type for shadow files.
    Returns None if parsing fails or confidence is too low.
    """
    if not raw_hash.hash:
        return None
    candidates = HashGuessService.guess_hash_types(raw_hash.hash, limit=1)
    if not candidates:
        return None
    best = candidates[0]
    if best.confidence < confidence_threshold:
        return None
    username = raw_hash.username if hasattr(raw_hash, "username") else None
    hashcat_hash = raw_hash.hash
    metadata = raw_hash.meta if hasattr(raw_hash, "meta") and raw_hash.meta else {}
    metadata = dict(metadata)
    metadata["hash_type_id"] = str(best.hash_type)
    metadata["hash_type_name"] = best.name
    return ParsedHashLine(
        username=username,
        hashcat_hash=hashcat_hash,
        metadata=metadata,
    )
