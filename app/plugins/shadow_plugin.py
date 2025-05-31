import re
from pathlib import Path

from app.core.services.hash_guess_service import HashGuessService
from app.models.raw_hash import RawHash

shadow_regex = re.compile(r"^(?P<username>[^:]+):(?P<hash>\$[0-9a-zA-Z]+\$[\w\./\$]+):")


def extract_hashes(path: Path, upload_task_id: int = 1) -> list[RawHash]:
    """
    Extract hashes from a Linux shadow or unshadowed file.
    Returns a list of RawHash objects (not yet committed to DB).
    """
    raw_hashes = []
    with path.open("r", encoding="utf-8", errors="replace") as f:
        for idx, raw_line in enumerate(f, 1):
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            m = shadow_regex.match(line)
            if not m:
                continue  # skip lines that don't match
            username = m.group("username")
            hashval = m.group("hash")
            # Guess hash type (default to 1800/sha512crypt if not found)
            guess = HashGuessService.guess_hash_types(hashval, limit=1)
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
    return raw_hashes
