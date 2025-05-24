# Phase 2b: Resource Management

This phase introduces full support for file-based resources within CipherSwarm. These include wordlists, rule files, masks, and other artifacts required for hashcat operations. All uploads are stored in MinIO using presigned URLs, with metadata tracked in the database.

This phase was previously Phase 4 but has been moved up to Phase 2b to enable Web UI support in Phase 3.

See [Phase 2 - Part 2](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md) for UI endpoint scaffolding. This document defines the backend service implementation.

---

## ✅ Goals

-   Integrate MinIO object storage for resource file handling
-   Store file metadata (size, line count, hash, type, etc.) in the DB
-   Issue presigned upload and download URLs to users and agents
-   Detect duplicates using content hashing
-   Support access control, sensitivity tagging, and validation
-   Allow inline editing of small text-based files (e.g. masks, rules)
-   Allow linking resources to attacks with GUID references
-   Ensure uploaded resources never orphan or bypass backend registration

---

## 🔄 Required Endpoints (Web UI)

| Method | Path                                          | Description                               |
| ------ | --------------------------------------------- | ----------------------------------------- |
| POST   | `/api/v1/web/resources/`                      | Register upload, return presigned PUT URL |
| GET    | `/api/v1/web/resources/`                      | List resources by type/project/visibility |
| GET    | `/api/v1/web/resources/{id}`                  | Get metadata                              |
| GET    | `/api/v1/web/resources/{id}/preview`          | First few lines of file                   |
| PATCH  | `/api/v1/web/resources/{id}`                  | Update metadata (name, tags, visibility)  |
| DELETE | `/api/v1/web/resources/{id}`                  | Delete resource if unlinked               |
| GET    | `/api/v1/web/resources/{id}/content`          | Get raw text (editable files only)        |
| PATCH  | `/api/v1/web/resources/{id}/content`          | Save updated content                      |
| POST   | `/api/v1/web/resources/{id}/refresh_metadata` | Revalidate size/checksum                  |

---

## 🔒 Access Control

| Role       | Permissions                                                                   |
| ---------- | ----------------------------------------------------------------------------- |
| Admin      | Full read/write/delete on all resources                                       |
| Power User | Can upload, view, edit, delete project-assigned resources                     |
| User       | Can view only non-sensitive resources or those explicitly assigned to project |

---

## 🧪 Validation & Deduplication

-   Use MD5 or SHA-256 hash to detect duplicates (stored in DB)
-   Prevent multiple uploads of identical files
-   Raise error if file is already linked to an active attack or campaign - Allow user to link to the existing resource rather than reuploading

---

## 📦 Resource Lifecycle

1. **Upload Registration**

    - Client posts metadata (`name`, `resource_type`, `project_id`, etc.)
    - Server returns presigned URL for upload
    - DB record created with `status = pending`

2. **Client Uploads File**

    - PUT request directly to MinIO using presigned URL

3. **Metadata Refresh**

    - Client triggers `POST /refresh_metadata`
    - Server:
        - Downloads file in thread
        - Computes hash, byte size, line count
        - Marks `status = active`

4. **Validation (Optional)**

    - Client may preview or validate lines via `GET /lines`

5. **Link to Attack**
    - Attack refers to resource by DB `id` or stable `guid`

---

## 🧩 Notes

-   Presigned URLs should expire after 15 minutes
-   Validate that uploaded files match declared `resource_type`
-   Inline editing should only be allowed if:
    -   Size < 1MB
    -   Line count < 5,000 (configurable)
-   Deletion must only be allowed if resource is not referenced by any attack

---

## 🧪 Test Cases

-   Upload a valid rule file and validate it line by line
-   Upload a duplicate wordlist and reject it
-   Upload large file and verify preview/edit is disabled
-   Attempt to delete linked resource → should fail
-   Upload, then link to attack, then unlink, then delete → should succeed

---

## 🧱 Implementation Tasks

-   [x] ✅ **Use `minio-py`** for all MinIO access (lightweight and sufficient for presigned flow) `task_id:minio.minio_py_support`
    -   All blocking operations must use `asyncio.to_thread(...)` inside FastAPI
-   [x] Add `MinioContainer` from `testcontainers.minio` support to enable integration tests for MinIO-based services `task_id:testcontainers.minio_support` (see [Testcontainers MinIO Support](notes/specific_tasks/testcontainers_minio_support.md))
-   [ ] Create `StorageService` class `task_id:minio.storage_service` - This is partially implemented in `app/core/services/storage_service.py`, but needs to be fully implemented and should be tested.
    - [x]  Stub out the class and functions and add tests for them. `test_id:minio.storage_service_stub`
    - [ ]  `presign_upload(bucket, key)`
    - [ ]  `presign_download(bucket, key)`
    - [ ]  `get_file_stats(bucket, key)` → byte size, line count, checksum
-   [ ] Create Pydantic + SQLAlchemy models for `AttackResourceFile` `task_id:minio.attack_resource_file_model`
    -   Fields: `name`, `resource_type`, `guid`, `bucket`, `key`, `size_bytes`, `line_count`, `checksum`, `sensitivity`, `project_id`
    -   Enum: `resource_type: [word_list, rule_list, mask_list, charset, dynamic_word_list]`
-   [ ] Add upload registration endpoint: `task_id:minio.upload_registration_endpoint`
    -   `POST /api/v1/web/resources/` returns:
        -   DB record ID
        -   presigned PUT URL
        -   file key format: `resources/{resource_id}/{filename}`
-   [ ] Add metadata refresh: `task_id:minio.metadata_refresh`
    -   `POST /resources/{id}/refresh_metadata` re-fetches size/lines/checksum
    -   Run in thread-safe context
-   [ ] Add content validation endpoint: `task_id:minio.content_validation_endpoint`
    -   `GET /resources/{id}/lines?validate=true`
    -   Uses line-level validators for syntax (mask, rule, etc.)
-   [ ] Add orphan audit: `task_id:minio.orphan_audit`
    -   Ensure no MinIO objects exist without matching DB rows
-   [ ] Audit existing endpoints in `app/api/v1/endpoints` that return resource download URLs and ensure they are returning the correct presigned URL
-   [ ] Audit existing web integration tests to ensure they are testing the correct presigned URL and do not contain TODOs related to presigned URLs
