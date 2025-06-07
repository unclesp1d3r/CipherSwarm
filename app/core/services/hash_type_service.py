import json
from pathlib import Path
from typing import Any

from loguru import logger
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.hash_type import HashType


class HashTypeService:
    """Service for managing hash types."""

    @staticmethod
    def load_hash_modes_from_json() -> dict[int, dict[str, Any]]:
        """Load hash modes from the JSON file."""
        json_path = (
            Path(__file__).parent.parent.parent / "resources" / "hash_modes.json"
        )

        if not json_path.exists():
            logger.error(f"Hash modes JSON file not found at {json_path}")
            return {}

        try:
            with json_path.open(encoding="utf-8") as f:
                data = json.load(f)

            # Convert string keys to integers and extract the hash_mode_map
            hash_mode_map = data.get("hash_mode_map", {})
            return {int(k): v for k, v in hash_mode_map.items()}
        except (json.JSONDecodeError, ValueError) as e:
            logger.error(f"Error loading hash modes JSON: {e}")
            return {}

    @staticmethod
    async def ensure_hash_type_exists(
        db: AsyncSession,
        mode: int,
        name: str | None = None,
        description: str | None = None,
    ) -> HashType:
        """Ensure a hash type exists in the database, creating it if necessary."""
        # Check if it already exists
        result = await db.execute(select(HashType).where(HashType.id == mode))
        hash_type = result.scalar_one_or_none()

        if hash_type:
            return hash_type

        # If name/description not provided, try to get from JSON
        if not name or not description:
            hash_modes = HashTypeService.load_hash_modes_from_json()
            if mode in hash_modes:
                mode_data = hash_modes[mode]
                name = name or mode_data.get("name", f"Mode {mode}")
                description = description or mode_data.get("category", "Unknown")

        # Create new hash type
        hash_type = HashType(
            id=mode,
            name=name or f"Mode {mode}",
            description=description or "Unknown",
        )

        db.add(hash_type)
        await db.commit()
        await db.refresh(hash_type)

        logger.info(f"Created hash type {mode}: {name}")
        return hash_type

    @staticmethod
    async def seed_hash_types_from_json(
        db: AsyncSession, limit: int | None = None
    ) -> int:
        """Seed hash types from the JSON file into the database."""
        hash_modes = HashTypeService.load_hash_modes_from_json()

        if not hash_modes:
            logger.warning("No hash modes found in JSON file")
            return 0

        created_count = 0
        modes_to_process = list(hash_modes.items())

        if limit:
            modes_to_process = modes_to_process[:limit]

        for mode, mode_data in modes_to_process:
            try:
                # Check if it already exists
                result = await db.execute(select(HashType).where(HashType.id == mode))
                existing = result.scalar_one_or_none()

                if not existing:
                    hash_type = HashType(
                        id=mode,
                        name=mode_data.get("name", f"Mode {mode}"),
                        description=mode_data.get("category", "Unknown"),
                    )
                    db.add(hash_type)
                    created_count += 1
            except (ValueError, TypeError) as e:
                logger.error(f"Error creating hash type {mode}: {e}")
                continue

        if created_count > 0:
            await db.commit()
            logger.info(f"Seeded {created_count} hash types from JSON")

        return created_count
