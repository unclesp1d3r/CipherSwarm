from datetime import datetime
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.attack import AttackMode
from app.models.attack_resource_file import AttackResourceType

from .shared import PaginatedResponse

EDITABLE_RESOURCE_TYPES: set[AttackResourceType] = {
    AttackResourceType.MASK_LIST,
    AttackResourceType.RULE_LIST,
    AttackResourceType.WORD_LIST,
    AttackResourceType.CHARSET,
}

EPHEMERAL_RESOURCE_TYPES: set[AttackResourceType] = {
    AttackResourceType.DYNAMIC_WORD_LIST,
    AttackResourceType.EPHEMERAL_WORD_LIST,
    AttackResourceType.EPHEMERAL_MASK_LIST,
    AttackResourceType.EPHEMERAL_RULE_LIST,
}

MAX_FILE_LABEL_LENGTH = 50


class ResourceLine(BaseModel):
    id: Annotated[
        int, Field(description="Unique line identifier (index in file or DB)")
    ]
    index: Annotated[int, Field(description="Line index (0-based)")]
    content: Annotated[str, Field(description="Content of the line")]
    valid: Annotated[
        bool,
        Field(
            description="Whether the line is valid according to resource type validation"
        ),
    ]
    error_message: Annotated[
        str | None, Field(description="Validation error message, if any")
    ] = None


class ResourceLineValidationError(BaseModel):
    line_index: Annotated[int, Field(description="Index of the line with error")]
    content: Annotated[str, Field(description="Content of the line with error")]
    valid: Annotated[bool, Field(default=False, description="Always false for errors")]
    message: Annotated[str, Field(description="Validation error message")]


class ResourceUploadMeta(BaseModel):
    file_name: Annotated[str, Field(description="Original file name")]
    resource_type: Annotated[
        AttackResourceType, Field(description="Type of the resource")
    ]


class ResourceUploadResponse(BaseModel):
    resource_id: Annotated[UUID, Field(description="UUID of the created resource")]
    presigned_url: Annotated[str, Field(description="Presigned S3 upload URL")]
    resource: Annotated[ResourceUploadMeta, Field(description="Resource metadata")]


class ResourceUploadFormSchema(BaseModel):
    allowed_resource_types: Annotated[
        list[AttackResourceType],
        Field(
            description="Allowed resource types for upload",
            examples=[["mask_list", "rule_list", "word_list", "charset"]],
        ),
    ]
    max_file_size_mb: Annotated[
        int, Field(description="Maximum file size in MB for upload", examples=[1])
    ]
    max_line_count: Annotated[
        int,
        Field(
            description="Maximum number of lines for in-browser editing",
            examples=[5000],
        ),
    ]
    minio_bucket: Annotated[
        str, Field(description="MinIO bucket name", examples=["cipherswarm-resources"])
    ]
    minio_endpoint: Annotated[
        str, Field(description="MinIO endpoint", examples=["minio:9000"])
    ]
    minio_secure: bool = Field(description="Whether MinIO uses HTTPS", examples=[False])
    model_config = ConfigDict(extra="ignore")


class ResourceBase(BaseModel):
    id: UUID
    file_name: str
    file_label: str | None = None
    resource_type: AttackResourceType
    line_count: int | None = None
    byte_size: int | None = None
    checksum: str = ""
    updated_at: datetime | None = None
    line_format: str | None = None
    line_encoding: str | None = None
    used_for_modes: list[str] | None = None
    source: str | None = None
    project_id: int | None = None
    unrestricted: bool | None = None  # True if resource is not project-restricted
    is_uploaded: bool = False
    tags: list[str] | None = None
    model_config = ConfigDict(from_attributes=True, extra="ignore")


class ResourcePreviewResponse(ResourceBase):
    preview_lines: list[str]
    preview_error: str | None = None
    max_preview_lines: int


class ResourceContentResponse(ResourceBase):
    content: str
    editable: bool


class ResourceUploadedResponse(ResourceBase):
    """Response for upload verification: resource metadata only."""


class WordlistItem(BaseModel):
    id: UUID
    file_name: str
    line_count: int | None = None


class WordlistDropdownResponse(BaseModel):
    wordlists: list[WordlistItem]


class RulelistItem(BaseModel):
    id: UUID
    file_name: str
    line_count: int | None = None


class RulelistDropdownResponse(BaseModel):
    rulelists: list[RulelistItem]


class ResourceLinesResponse(BaseModel):
    lines: list[ResourceLine]
    resource_id: UUID


class ResourceListItem(ResourceBase):
    pass  # Inherits all fields from ResourceBase


class AttackBasic(BaseModel):
    id: int
    name: str


class ResourceDetailResponse(ResourceBase):
    attacks: list[AttackBasic]


class ResourceListResponse(PaginatedResponse[ResourceListItem]):
    resource_type: AttackResourceType | None = None


class ResourceUpdateRequest(BaseModel):
    file_name: Annotated[str | None, Field(None, description="Resource file name")]
    file_label: Annotated[
        str | None,
        Field(
            None,
            max_length=MAX_FILE_LABEL_LENGTH,
            description=f"Freeform label for the resource (up to {MAX_FILE_LABEL_LENGTH} chars)",
        ),
    ]
    project_id: Annotated[
        int | None, Field(None, description="Project ID to associate with resource")
    ]
    source: Annotated[str | None, Field(None, description="Resource source")]
    unrestricted: Annotated[
        bool | None, Field(None, description="If true, resource is globally accessible")
    ]
    tags: Annotated[
        list[str] | None, Field(None, description="List of user-provided tags")
    ]
    used_for_modes: Annotated[
        list[AttackMode] | None,
        Field(None, description="List of attack modes this resource is used for"),
    ]
    line_format: Annotated[
        str | None, Field(None, description="Line format for resource")
    ]
    line_encoding: Annotated[
        str | None, Field(None, description="Line encoding for resource")
    ]
    model_config = ConfigDict(extra="forbid")
