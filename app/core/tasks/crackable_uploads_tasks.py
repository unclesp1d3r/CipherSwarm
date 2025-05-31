import tempfile
from collections.abc import Sequence
from datetime import UTC, datetime
from pathlib import Path

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.config import settings
from app.core.exceptions import PluginExecutionError
from app.core.logging import logger
from app.core.services.storage_service import get_storage_service
from app.models.campaign import Campaign, CampaignState
from app.models.hash_item import HashItem
from app.models.hash_list import HashList
from app.models.hash_upload_task import HashUploadStatus, HashUploadTask
from app.models.raw_hash import RawHash
from app.models.upload_error_entry import UploadErrorEntry
from app.models.upload_resource_file import UploadResourceFile
from app.plugins.dispatcher import dispatch_extract_hashes
from app.plugins.shadow_plugin import parse_hash_line


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
    for hi in hash_items:
        hash_list.items.append(hi)
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


async def process_uploaded_hash_file(upload_id: int, db: AsyncSession) -> None:
    """
    Orchestrate the full crackable upload pipeline.
    """
    tmp_path: Path | None = None
    task = None
    try:
        task = await load_upload_task(upload_id, db)
        resource = await load_upload_resource_file(task.filename, db)
        tmp_path = await download_upload_file(resource)
        await update_task_status_running(task, db)
        ext = resource.file_name.split(".")[-1]
        raw_hashes = extract_hashes_with_plugin(tmp_path, ext, task.id)
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
        logger.info(
            f"process_uploaded_hash_file for upload_id={upload_id} complete: status={task.status}"
        )
    except BaseException as e:  # noqa: BLE001, RUF100
        # Broad catch is required for background task safety to ensure all errors are logged and status is set.
        logger.error(f"Fatal error in process_uploaded_hash_file: {e}")
        if task is not None:
            task.status = HashUploadStatus.FAILED
            await db.commit()
        raise
    finally:
        if tmp_path is not None and tmp_path.exists():
            tmp_path.unlink()
