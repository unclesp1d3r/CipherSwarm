import tempfile
from collections.abc import Sequence
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

from app.core.config import settings
from app.core.exceptions import PluginExecutionError
from app.core.logging import logger
from app.core.services.storage_service import get_storage_service
from app.models.attack import Attack, AttackMode, AttackState
from app.models.attack_resource_file import AttackResourceFile, AttackResourceType
from app.models.campaign import Campaign, CampaignState
from app.models.hash_item import HashItem
from app.models.hash_list import HashList
from app.models.hash_upload_task import HashUploadStatus, HashUploadTask
from app.models.raw_hash import RawHash
from app.models.upload_error_entry import UploadErrorEntry
from app.models.upload_resource_file import UploadResourceFile
from app.plugins.dispatcher import dispatch_extract_hashes
from app.plugins.shadow_plugin import parse_hash_line

# Constants for wordlist generation
MIN_USERNAME_LENGTH = 3
MIN_PASSWORD_LENGTH = 3
MAX_PASSWORD_LENGTH = 64
NTLM_PARTS_COUNT = 4


async def load_upload_task(upload_id: int, db: AsyncSession) -> HashUploadTask:
    """Load the HashUploadTask by ID or raise."""
    task = (
        await db.execute(select(HashUploadTask).where(HashUploadTask.id == upload_id))
    ).scalar_one_or_none()
    if not task:
        raise ValueError(f"HashUploadTask {upload_id} not found")
    return task


async def load_upload_resource_file(
    filename: str, db: AsyncSession
) -> UploadResourceFile:
    """Load the UploadResourceFile by filename or raise."""
    resource = (
        await db.execute(
            select(UploadResourceFile).where(UploadResourceFile.file_name == filename)
        )
    ).scalar_one_or_none()
    if not resource:
        raise ValueError(f"UploadResourceFile for filename {filename} not found")
    return resource


async def download_upload_file(resource: UploadResourceFile) -> Path:
    """Download the file from MinIO to a temp location and return the path."""
    storage_service = get_storage_service()
    bucket = settings.MINIO_BUCKET
    object_name = str(resource.id)
    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        tmp_path = Path(tmp.name)
        obj = storage_service.client.get_object(bucket, object_name)
        for chunk in obj.stream(4096):
            tmp.write(chunk)
        obj.close()
    return tmp_path


async def create_temp_file_from_content(resource: UploadResourceFile) -> Path:
    """Create a temporary file from text content stored in the database."""
    if not resource.content or "raw_text" not in resource.content:
        raise ValueError("Resource does not contain text content")

    content = str(resource.content["raw_text"])
    with tempfile.NamedTemporaryFile(
        mode="w", delete=False, suffix=".txt", encoding="utf-8"
    ) as tmp:
        tmp.write(content)
    return Path(tmp.name)


async def update_task_status_running(task: HashUploadTask, db: AsyncSession) -> None:
    """Set the task status to RUNNING and update started_at."""
    task.status = HashUploadStatus.RUNNING
    task.started_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(task)


def extract_hashes_with_plugin(
    tmp_path: Path, ext: str, upload_task_id: int
) -> list[RawHash]:
    """Extract hashes using the plugin dispatcher."""
    try:
        return dispatch_extract_hashes(tmp_path, ext, upload_task_id)
    except PluginExecutionError as e:
        logger.error(f"Plugin execution failed: {e}")
        raise
    except Exception as e:
        logger.error(f"Unknown error in plugin: {e}")
        raise


async def insert_raw_hashes(raw_hashes: Sequence[RawHash], db: AsyncSession) -> None:
    """Insert RawHash objects into the DB."""
    for rh in raw_hashes:
        db.add(rh)
    await db.commit()


async def create_hashlist_and_campaign(
    task: HashUploadTask,
    resource: UploadResourceFile,
    raw_hashes: Sequence[RawHash],
    db: AsyncSession,
) -> tuple[HashList, Campaign]:
    """Create HashList and Campaign with is_unavailable=True, link to task."""
    hash_type_id = raw_hashes[0].hash_type_id if raw_hashes else 1800
    hash_list = HashList(
        name=f"Upload {task.filename}",
        description=f"Imported from upload task {task.id}",
        project_id=resource.project_id or 1,
        hash_type_id=hash_type_id,
        is_unavailable=True,
    )
    db.add(hash_list)
    await db.commit()
    await db.refresh(hash_list)
    campaign = Campaign(
        name=f"Upload {task.filename}",
        description=f"Imported from upload task {task.id}",
        project_id=resource.project_id or 1,
        hash_list_id=hash_list.id,
        is_unavailable=True,
        state=CampaignState.DRAFT,
    )
    db.add(campaign)
    await db.commit()
    await db.refresh(campaign)
    task.hash_list_id = hash_list.id
    task.campaign_id = campaign.id
    await db.commit()
    return hash_list, campaign


async def parse_and_insert_hashitems(
    task: HashUploadTask,
    raw_hashes: Sequence[RawHash],
    hash_list: HashList,
    db: AsyncSession,
) -> int:
    """Parse RawHash objects, insert HashItem objects, log errors. Returns error count."""
    error_count = 0
    hash_items = []
    for rh in raw_hashes:
        parsed = parse_hash_line(rh)
        if parsed is None:
            error = UploadErrorEntry(
                upload_id=task.id,
                line_number=rh.line_number,
                raw_line=rh.hash,
                error_message="Failed to parse hash line or low confidence",
            )
            db.add(error)
            error_count += 1
            continue
        hi = HashItem(
            hash=parsed.hashcat_hash,
            salt=None,
            meta=parsed.metadata,
            plain_text=None,
        )
        db.add(hi)
        hash_items.append(hi)
    await db.commit()
    # Eagerly reload hash_list with items to avoid MissingGreenlet
    result = await db.execute(
        select(HashList)
        .options(selectinload(HashList.items))
        .where(HashList.id == hash_list.id)
    )
    hash_list_with_items = result.scalar_one()
    for hi in hash_items:
        hash_list_with_items.items.append(hi)
    await db.commit()
    return error_count


async def update_status_fields(
    task: HashUploadTask,
    hash_list: HashList,
    campaign: Campaign,
    error_count: int,
    hash_items: Sequence[HashItem],
    db: AsyncSession,
) -> None:
    """Update status fields for HashList, Campaign, and Task."""
    if error_count == 0 and hash_items:
        hash_list.is_unavailable = False
        campaign.is_unavailable = False
        task.status = HashUploadStatus.COMPLETED
    elif error_count > 0 and hash_items:
        hash_list.is_unavailable = False
        campaign.is_unavailable = False
        task.status = HashUploadStatus.PARTIAL_FAILURE
    else:
        hash_list.is_unavailable = True
        campaign.is_unavailable = True
        task.status = HashUploadStatus.FAILED
    task.finished_at = datetime.now(UTC)
    task.error_count = error_count
    await db.commit()


async def extract_raw_hashes(
    resource: UploadResourceFile,
    task: HashUploadTask,
    tmp_path: Path,
    upload_id: int,
    db: AsyncSession,
) -> list[RawHash] | None:
    """Extract raw hashes from either text content or file using plugins."""
    if resource.source == "text_blob":
        # Extract hashes directly from the stored content
        if not resource.content or "lines" not in resource.content:
            task.status = HashUploadStatus.FAILED
            await db.commit()
            logger.error(
                f"Upload processing failed: no content in text blob for upload_id={upload_id}"
            )
            return None

        # Create RawHash objects from the text content lines
        raw_hashes = []
        lines = resource.content["lines"]
        if isinstance(lines, list):
            for i, line in enumerate(lines, 1):
                raw_hash = RawHash(
                    upload_task_id=task.id,
                    line_number=i,
                    hash=str(line).strip(),
                    hash_type_id=1800,  # Default to sha512crypt for now
                )
                raw_hashes.append(raw_hash)
        return raw_hashes

    # For file uploads, use the plugin system
    ext = resource.file_name.split(".")[-1]
    try:
        return extract_hashes_with_plugin(tmp_path, ext, task.id)
    except PluginExecutionError:
        # Mark both task and resource as failed
        task.status = HashUploadStatus.FAILED
        if resource is not None:
            resource.is_uploaded = False  # Mark as not uploaded/failed
            await db.commit()
        await db.commit()
        logger.error(
            f"Upload processing failed: plugin error for upload_id={upload_id}"
        )
        return None


async def process_uploaded_hash_file(upload_id: int, db: AsyncSession) -> None:
    """
    Orchestrate the full crackable upload pipeline.
    """
    tmp_path: Path | None = None
    task = None
    resource = None
    try:
        task = await load_upload_task(upload_id, db)
        resource = await load_upload_resource_file(task.filename, db)

        # Handle different resource sources
        if resource.source == "text_blob":
            tmp_path = await create_temp_file_from_content(resource)
        else:
            tmp_path = await download_upload_file(resource)

        await update_task_status_running(task, db)

        # Extract hashes based on resource source
        raw_hashes = await extract_raw_hashes(resource, task, tmp_path, upload_id, db)
        if raw_hashes is None:
            return  # Error already handled in extract_raw_hashes
        if not raw_hashes:
            task.status = HashUploadStatus.FAILED
            if resource is not None:
                resource.is_uploaded = False
                await db.commit()
            await db.commit()
            logger.error(
                f"Upload processing failed: no hashes extracted for upload_id={upload_id}"
            )
            return
        await insert_raw_hashes(raw_hashes, db)
        hash_list, campaign = await create_hashlist_and_campaign(
            task, resource, raw_hashes, db
        )
        error_count = await parse_and_insert_hashitems(task, raw_hashes, hash_list, db)
        await db.refresh(hash_list, attribute_names=["items"])
        hash_items = hash_list.items
        await update_status_fields(
            task, hash_list, campaign, error_count, hash_items, db
        )

        # Create dynamic wordlist attack if usernames/passwords are available
        if task.status in [
            HashUploadStatus.COMPLETED,
            HashUploadStatus.PARTIAL_FAILURE,
        ]:
            try:
                dynamic_attack = await create_dynamic_wordlist_attack(
                    campaign, raw_hashes, db
                )
                if dynamic_attack:
                    logger.info(
                        f"Created dynamic wordlist attack {dynamic_attack.id} for upload {upload_id}"
                    )
            except Exception as e:  # noqa: BLE001
                logger.warning(
                    f"Failed to create dynamic wordlist attack for upload {upload_id}: {e}"
                )
                # Don't fail the entire upload process if dynamic attack creation fails

        logger.info(
            f"process_uploaded_hash_file for upload_id={upload_id} complete: status={task.status}"
        )
    except BaseException as e:  # noqa: BLE001, RUF100
        # Broad catch is required for background task safety to ensure all errors are logged and status is set.
        logger.error(f"Fatal error in process_uploaded_hash_file: {e}")
        if task is not None:
            task.status = HashUploadStatus.FAILED
            await db.commit()
        if resource is not None:
            resource.is_uploaded = False
            await db.commit()
        raise
    finally:
        if tmp_path is not None and tmp_path.exists():
            tmp_path.unlink()


def _extract_username_variations(username: str) -> set[str]:
    """Extract username variations for wordlist generation."""
    variations = {username}
    variations.add(username.lower())
    variations.add(username.upper())
    variations.add(username.capitalize())
    variations.add(f"{username}123")
    variations.add(f"{username}1")
    variations.add(f"{username}2024")
    variations.add(f"{username}!")
    variations.add(f"123{username}")
    return variations


def _extract_passwords_from_metadata(meta: dict[str, Any]) -> set[str]:
    """Extract passwords from metadata dictionary."""
    passwords = set()

    # Look for plaintext passwords in metadata
    for key in ["password", "plaintext", "plain", "pass"]:
        if key in meta:
            password = str(meta[key]).strip()
            if password and len(password) >= MIN_PASSWORD_LENGTH:
                passwords.add(password)

    # Extract from NTLM pairs format (username:hash:password)
    if "ntlm_password" in meta:
        password = str(meta["ntlm_password"]).strip()
        if password and len(password) >= MIN_PASSWORD_LENGTH:
            passwords.add(password)

    return passwords


def _extract_username_from_hash_line(hash_line: str) -> set[str]:
    """Extract username from hash line (e.g., NTLM format)."""
    usernames = set()

    if ":" in hash_line:
        parts = hash_line.split(":")
        # Check for NTLM format: username:uid:lm_hash:ntlm_hash
        if len(parts) >= NTLM_PARTS_COUNT:
            username_part = parts[0].strip()
            if username_part and len(username_part) >= MIN_USERNAME_LENGTH:
                usernames.add(username_part)
                usernames.add(username_part.lower())
                usernames.add(f"{username_part}123")

    return usernames


async def extract_usernames_and_passwords_for_wordlist(
    raw_hashes: Sequence[RawHash],
) -> list[str]:
    """
    Extract usernames and passwords from RawHash objects to create a dynamic wordlist.

    This function extracts:
    - Usernames from shadow files, NTLM pairs, etc.
    - Passwords from cracked zip headers or other sources where plaintext is available
    - Common variations and transformations of usernames

    Args:
        raw_hashes: Sequence of RawHash objects from uploaded content

    Returns:
        List of unique wordlist entries derived from the uploaded content
    """
    wordlist_entries = set()

    for raw_hash in raw_hashes:
        # Skip invalid or placeholder hashes
        if not raw_hash.hash or raw_hash.hash.strip() in ["*", "", "NO PASSWORD***"]:
            continue

        # Extract username if available
        if raw_hash.username:
            username = raw_hash.username.strip()
            if username and len(username) >= MIN_USERNAME_LENGTH:
                wordlist_entries.update(_extract_username_variations(username))

        # Extract passwords from metadata if available
        if raw_hash.meta and isinstance(raw_hash.meta, dict):
            wordlist_entries.update(_extract_passwords_from_metadata(raw_hash.meta))

        # Parse hash line for additional context
        wordlist_entries.update(_extract_username_from_hash_line(raw_hash.hash))

    # Convert to sorted list and filter out very short entries
    filtered_entries = [
        entry
        for entry in wordlist_entries
        if MIN_PASSWORD_LENGTH
        <= len(entry)
        <= MAX_PASSWORD_LENGTH  # Reasonable password length limits
    ]

    logger.info(
        f"Generated {len(filtered_entries)} wordlist entries from {len(raw_hashes)} raw hashes"
    )
    return sorted(filtered_entries)


async def create_dynamic_wordlist_attack(
    campaign: Campaign,
    raw_hashes: Sequence[RawHash],
    db: AsyncSession,
) -> Attack | None:
    """
    Create a dictionary attack with an ephemeral wordlist derived from uploaded content.

    Args:
        campaign: The campaign to add the attack to
        raw_hashes: Raw hashes from the upload to extract wordlist data from
        db: Database session

    Returns:
        Created Attack object or None if no wordlist could be generated
    """
    # Extract wordlist entries from the uploaded content
    wordlist_entries = await extract_usernames_and_passwords_for_wordlist(raw_hashes)

    if not wordlist_entries:
        logger.info(
            "No usernames or passwords found in uploaded content, skipping dynamic wordlist attack"
        )
        return None

    # Create ephemeral wordlist resource
    ephemeral_wordlist = AttackResourceFile(
        id=uuid4(),
        file_name="dynamic_wordlist_from_upload.txt",
        download_url="",  # Not downloadable from MinIO
        checksum="",  # Not applicable
        guid=uuid4(),
        resource_type=AttackResourceType.EPHEMERAL_WORD_LIST,
        line_format="freeform",
        line_encoding="utf-8",
        used_for_modes=[AttackMode.DICTIONARY],
        source="dynamic_upload",
        line_count=len(wordlist_entries),
        byte_size=sum(len(entry.encode("utf-8")) for entry in wordlist_entries),
        content={"lines": wordlist_entries},
    )
    db.add(ephemeral_wordlist)
    await db.flush()  # Get the ID

    # Get the maximum position for attacks in this campaign
    max_pos_result = await db.execute(
        select(Attack.position)
        .where(Attack.campaign_id == campaign.id)
        .order_by(Attack.position.desc())
        .limit(1)
    )
    max_position = max_pos_result.scalar() or -1

    # Create dictionary attack using the ephemeral wordlist
    attack = Attack(
        name="Dynamic Dictionary (From Upload)",
        description=f"Dictionary attack using {len(wordlist_entries)} words extracted from uploaded content",
        attack_mode=AttackMode.DICTIONARY,
        campaign_id=campaign.id,
        hash_list_id=campaign.hash_list_id,
        hash_list_url="",  # Not used for campaign-based attacks
        hash_list_checksum="",  # Not used for campaign-based attacks
        word_list_id=ephemeral_wordlist.id,
        state=AttackState.PENDING,
        position=max_position + 1,
        priority=1,  # High priority for dynamic attacks
    )
    db.add(attack)
    await db.commit()
    await db.refresh(attack)

    logger.info(
        f"Created dynamic dictionary attack {attack.id} with {len(wordlist_entries)} words for campaign {campaign.id}"
    )
    return attack
