from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.attack_resource_file import AttackResourceType
from app.schemas.attack import AttackSummary

# Resource type constants
EPHEMERAL_RESOURCE_TYPES = {
    AttackResourceType.EPHEMERAL_WORD_LIST,
    AttackResourceType.EPHEMERAL_MASK_LIST,
    AttackResourceType.EPHEMERAL_RULE_LIST,
    AttackResourceType.DYNAMIC_WORD_LIST,
}

EDITABLE_RESOURCE_TYPES = {
    AttackResourceType.WORD_LIST,
    AttackResourceType.RULE_LIST,
    AttackResourceType.MASK_LIST,
    AttackResourceType.CHARSET,
}

MAX_FILE_LABEL_LENGTH = 50

# Re-export AttackBasic for backward compatibility
AttackBasic = AttackSummary


class ResourceLine(BaseModel):
    """Schema for a single line in a resource file."""

    id: int | None = Field(None, description="Line ID")
    index: int | None = Field(None, description="Line index")
    line_number: int = Field(..., description="Line number (1-based)")
    content: str = Field(..., description="Line content")
    is_valid: bool = Field(True, description="Whether the line is valid")
    error_message: str | None = Field(None, description="Error message if invalid")


class ResourceLineValidationError(BaseModel):
    """Schema for resource line validation errors."""

    line_number: int = Field(..., description="Line number with error")
    error_message: str = Field(..., description="Error message")
    line_content: str = Field(..., description="Content of the line with error")


class ResourceListItem(BaseModel):
    """Schema for resource list items."""

    id: UUID = Field(..., description="Resource ID")
    file_name: str = Field(..., description="Resource file name")
    resource_type: str = Field(..., description="Resource type")
    line_count: int = Field(..., description="Number of lines")
    byte_size: int = Field(..., description="File size in bytes")
    is_uploaded: bool = Field(..., description="Whether the resource is uploaded")
    created_at: datetime = Field(..., description="Creation timestamp")


class ResourceContentResponse(BaseModel):
    """Response schema for resource content."""

    id: UUID = Field(..., description="Resource ID")
    file_name: str = Field(..., description="Resource file name")
    resource_type: str = Field(..., description="Resource type")
    editable: bool = Field(..., description="Whether the resource is editable")
    content: str = Field(..., description="Resource content")


class ResourceDetailResponse(BaseModel):
    """Response schema for detailed resource information."""

    id: str = Field(..., description="Resource ID")
    file_name: str = Field(..., description="Resource file name")
    file_label: str | None = Field(None, description="Resource label")
    resource_type: str = Field(..., description="Resource type")
    line_count: int = Field(..., description="Number of lines")
    byte_size: int = Field(..., description="File size in bytes")
    checksum: str | None = Field(None, description="File checksum")
    updated_at: datetime = Field(..., description="Last update timestamp")
    line_format: str | None = Field(None, description="Line format")
    line_encoding: str | None = Field(None, description="Line encoding")
    used_for_modes: list[str] = Field(
        default_factory=list, description="Hash modes this resource is used for"
    )
    source: str | None = Field(None, description="Resource source")
    project_id: int | None = Field(None, description="Project ID")
    unrestricted: bool = Field(..., description="Whether resource is unrestricted")
    is_uploaded: bool = Field(..., description="Whether the resource is uploaded")
    tags: list[str] = Field(default_factory=list, description="Resource tags")
    attacks: list[AttackBasic] = Field(
        default_factory=list, description="Associated attacks"
    )


class ResourceLinesResponse(BaseModel):
    """Response schema for resource lines."""

    resource_id: str = Field(..., description="Resource ID")
    lines: list[ResourceLine] = Field(..., description="Resource lines")


class ResourceListResponse(BaseModel):
    """Response schema for resource list."""

    items: list[ResourceListItem] = Field(..., description="Resource items")
    total: int = Field(..., description="Total number of resources")
    page: int = Field(..., description="Current page")
    page_size: int = Field(..., description="Page size")
    total_pages: int = Field(..., description="Total number of pages")


class ResourcePreviewResponse(BaseModel):
    """Response schema for resource preview."""

    id: str = Field(..., description="Resource ID")
    file_name: str = Field(..., description="Resource file name")
    resource_type: str = Field(..., description="Resource type")
    line_count: int = Field(..., description="Number of lines")
    byte_size: int = Field(..., description="File size in bytes")
    updated_at: datetime = Field(..., description="Last update timestamp")
    line_format: str | None = Field(None, description="Line format")
    line_encoding: str | None = Field(None, description="Line encoding")
    used_for_modes: list[str] = Field(
        default_factory=list, description="Hash modes this resource is used for"
    )
    source: str | None = Field(None, description="Resource source")
    project_id: int | None = Field(None, description="Project ID")
    unrestricted: bool = Field(..., description="Whether resource is unrestricted")
    preview_lines: list[str] = Field(..., description="Preview lines")
    preview_error: str | None = Field(None, description="Preview error message")
    max_preview_lines: int = Field(..., description="Maximum number of preview lines")


class ResourceUpdateRequest(BaseModel):
    """Request schema for updating a resource."""

    file_name: str | None = Field(None, description="Resource file name")
    file_label: str | None = Field(None, description="Resource label", max_length=50)
    tags: list[str] | None = Field(None, description="Resource tags")
    project_id: int | None = Field(None, description="Project ID")
    source: str | None = Field(None, description="Resource source")
    unrestricted: bool | None = Field(
        None, description="Whether resource is unrestricted"
    )
    used_for_modes: list[str] | None = Field(
        None, description="Hash modes this resource is used for"
    )
    line_format: str | None = Field(None, description="Line format")
    line_encoding: str | None = Field(None, description="Line encoding")


class ResourceUploadMeta(BaseModel):
    """Metadata for uploaded resource."""

    file_name: str = Field(..., description="Resource file name")
    resource_type: str | None = Field(None, description="Resource type")


class ResourceUploadResponse(BaseModel):
    """Response schema for resource upload."""

    resource_id: str = Field(..., description="Resource ID")
    presigned_url: str | None = Field(None, description="Presigned upload URL")
    resource: ResourceUploadMeta = Field(..., description="Resource metadata")


class ResourceUploadedResponse(BaseModel):
    """Response schema for uploaded resource confirmation."""

    id: str = Field(..., description="Resource ID")
    file_name: str = Field(..., description="Resource file name")
    resource_type: str = Field(..., description="Resource type")
    line_count: int = Field(..., description="Number of lines")
    byte_size: int = Field(..., description="File size in bytes")
    checksum: str | None = Field(None, description="File checksum")
    is_uploaded: bool = Field(..., description="Whether the resource is uploaded")
    minio_bucket: str = Field(..., description="MinIO bucket name")

    model_config = ConfigDict(from_attributes=True)


class ResourceUploadFormSchema(BaseModel):
    """Schema for resource upload form configuration."""

    allowed_resource_types: list[str] = Field(..., description="Allowed resource types")
    max_file_size_mb: int = Field(..., description="Maximum file size in MB")
    max_line_count: int = Field(..., description="Maximum line count")
    minio_bucket: str = Field(..., description="MinIO bucket name")
    minio_endpoint: str = Field(..., description="MinIO endpoint URL")
    minio_secure: bool = Field(..., description="Whether MinIO uses secure connections")


class WordlistItem(BaseModel):
    """Schema for wordlist dropdown items."""

    id: str = Field(..., description="Wordlist ID")
    file_name: str = Field(..., description="Wordlist file name")
    line_count: int = Field(..., description="Number of lines")


class WordlistDropdownResponse(BaseModel):
    """Response schema for wordlist dropdown."""

    wordlists: list[WordlistItem] = Field(..., description="Wordlist items")


class RulelistItem(BaseModel):
    """Schema for rulelist dropdown items."""

    id: str = Field(..., description="Rulelist ID")
    file_name: str = Field(..., description="Rulelist file name")
    line_count: int = Field(..., description="Number of lines")


class RulelistDropdownResponse(BaseModel):
    """Response schema for rulelist dropdown."""

    rulelists: list[RulelistItem] = Field(..., description="Rulelist items")


class UploadProcessingStep(BaseModel):
    """Schema for upload processing steps."""

    step: str = Field(..., description="Processing step name")
    status: str = Field(..., description="Step status")
    message: str | None = Field(None, description="Step message")


class UploadErrorEntryOut(BaseModel):
    """Schema for upload error entries."""

    line_number: int = Field(..., description="Line number with error")
    error_message: str = Field(..., description="Error message")
    content: str = Field(..., description="Content of the line with error")
    severity: str = Field(default="error", description="Error severity level")


class UploadErrorEntryListResponse(BaseModel):
    """Response schema for upload error entries."""

    items: list[UploadErrorEntryOut] = Field(..., description="Upload error entries")
    total: int = Field(..., description="Total number of error entries")
    page: int = Field(..., description="Current page number")
    page_size: int = Field(..., description="Number of items per page")
    total_pages: int = Field(..., description="Total number of pages")


class UploadStatusOut(BaseModel):
    """Schema for upload status."""

    status: str = Field(..., description="Current status of the upload task")
    started_at: str | None = Field(None, description="ISO8601 start time")
    finished_at: str | None = Field(None, description="ISO8601 finish time")
    error_count: int = Field(..., description="Number of errors encountered")
    hash_type: str | None = Field(None, description="Inferred hash type name")
    hash_type_id: int | None = Field(None, description="Inferred hash type ID")
    preview: list[str] = Field(
        default_factory=list, description="Preview of extracted hashes"
    )
    validation_state: str = Field(
        ..., description="Validation state: valid, invalid, partial, pending"
    )
    upload_resource_file_id: str = Field(
        ..., description="UUID of the upload resource file"
    )
    upload_task_id: int = Field(..., description="ID of the upload task")
    processing_steps: list[UploadProcessingStep] = Field(
        default_factory=list,
        description="Detailed information about each processing step",
    )
    current_step: str | None = Field(
        None, description="Name of the currently executing step"
    )
    total_hashes_found: int | None = Field(
        None, description="Total number of hashes found in the file"
    )
    total_hashes_parsed: int | None = Field(
        None, description="Total number of hashes successfully parsed"
    )
    campaign_id: int | None = Field(
        None, description="ID of the created campaign, if available"
    )
    hash_list_id: int | None = Field(
        None, description="ID of the created hash list, if available"
    )
    overall_progress_percentage: int | None = Field(
        None, description="Overall progress percentage of the upload task"
    )


class ResourceUrlResponse(BaseModel):
    """Response schema for resource URL requests."""

    resource_id: int = Field(..., description="The ID of the resource")
    download_url: str = Field(
        ..., description="Presigned URL for downloading the resource"
    )
    expires_at: datetime = Field(..., description="When the presigned URL expires")
    expected_hash: str | None = Field(
        None, description="Expected hash of the file for verification"
    )
    file_size: int | None = Field(None, description="Size of the file in bytes")
    content_type: str = Field(
        "application/octet-stream", description="MIME type of the resource"
    )


class ResourceBase(BaseModel):
    """Base schema for resources."""

    name: str = Field(..., description="Resource name")
    description: str | None = Field(None, description="Resource description")
    resource_type: str = Field(
        ..., description="Type of resource (wordlist, rules, etc.)"
    )
    file_path: str = Field(..., description="Path to the resource file")
    file_hash: str | None = Field(None, description="Hash of the resource file")
    file_size: int | None = Field(
        None, description="Size of the resource file in bytes"
    )
    content_type: str = Field(
        "application/octet-stream", description="MIME type of the resource"
    )


class ResourceCreate(ResourceBase):
    """Schema for creating a new resource."""


class ResourceUpdate(BaseModel):
    """Schema for updating a resource."""

    name: str | None = None
    description: str | None = None
    resource_type: str | None = None
    file_path: str | None = None
    file_hash: str | None = None
    file_size: int | None = None
    content_type: str | None = None


class ResourceInDBBase(ResourceBase):
    """Base schema for resources stored in database."""

    id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class Resource(ResourceInDBBase):
    """Schema for returning resource data to clients."""


class ResourceInDB(ResourceInDBBase):
    """Schema for resource data stored in database."""
