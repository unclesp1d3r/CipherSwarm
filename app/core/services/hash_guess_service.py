# pyright: reportMissingTypeStubs=false
# pyright: reportGeneralTypeIssues=false

from typing import Any

from loguru import logger

try:
    from name_that_hash import runner
except ImportError:
    runner = None


class HashGuessCandidate:
    def __init__(self, hash_type: int, name: str, confidence: float) -> None:
        self.hash_type = hash_type
        self.name = name
        self.confidence = confidence

    def to_dict(self) -> dict[str, Any]:
        return {
            "hash_type": self.hash_type,
            "name": self.name,
            "confidence": self.confidence,
        }


class HashGuessService:
    """
    Service for analyzing unknown hash material and inferring likely hash types using Name-That-Hash.
    """

    @staticmethod
    def normalize_input(raw: str) -> list[str]:
        """
        Normalize input by splitting lines, stripping usernames/delimiters, and removing blanks.
        Always returns only the hash portion (after the first colon, if present).
        """
        lines = [line.strip() for line in raw.splitlines() if line.strip()]
        normalized = []
        for original_line in lines:
            line = original_line
            if ":" in line:
                # Only keep the part after the first colon
                line = line.split(":", 1)[1]
            line = line.strip()
            if line:
                normalized.append(line)
        return normalized

    @staticmethod
    def guess_hash_types(
        hash_material: str,
        limit: int = 5,
    ) -> list[HashGuessCandidate]:
        """
        Analyze hash material and return ranked hashcat-compatible type candidates.
        """
        if runner is None:
            logger.error("name-that-hash is not installed or importable")
            raise ImportError("name-that-hash is required for hash guessing")
        hashes = HashGuessService.normalize_input(hash_material)
        if not hashes:
            return []
        try:
            # Use the documented API: returns a dict keyed by hash, each value is a list of candidates
            result = runner.api_return_hashes_as_dict(hashes, {"popular_only": False})
        except ImportError as err:
            logger.error(f"Error running name-that-hash: {err}")
            raise ImportError("name-that-hash is required for hash guessing") from err
        except ValueError as err:
            logger.error(f"Value error in hash guessing: {err}")
            raise ValueError(str(err)) from err
        except Exception as err:  # noqa: BLE001
            logger.error(f"Unexpected error in hash guessing: {err}", exc_info=True)
            return []
        # Collect all candidates, flatten, and dedupe by (hash_type, name), keep first (most popular)
        seen = set()
        candidates = []
        for guesses in result.values():
            for idx, guess in enumerate(guesses):
                hashcat_mode = guess.get("hashcat")
                name = guess.get("name")
                if hashcat_mode is not None and name:
                    key = (hashcat_mode, name)
                    if key not in seen:
                        # Confidence is 1.0 for the first (most popular), then decreases
                        confidence = 1.0 - (idx * 0.1)
                        candidates.append(
                            HashGuessCandidate(hashcat_mode, name, confidence)
                        )
                        seen.add(key)
        # Sort by confidence descending
        candidates.sort(key=lambda c: c.confidence, reverse=True)
        return candidates[:limit]
