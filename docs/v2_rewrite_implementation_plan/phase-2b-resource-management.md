# Phase 2b: Resource Management

This phase adds robust support for file-based resource uploads and management within CipherSwarm. These resources include wordlists, rule files, mask files, and other artifacts required for hashcat operations.

This phase was previously phase 4, but has been moved to phase 2b to allow for the resource management to be completed before the web UI is fully implemented. Many of the required steps have been completed as part of [Phase 2 - Part 2](phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md) and should be reviewed before starting.

## ✅ Goals

-   Implement backend file handling and metadata storage
-   Integrate S3-compatible MinIO storage service
-   Enable resource visibility, sensitivity tagging, and access control
-   Provide API endpoints and UI backend logic to manage uploads/downloads
-   The agent and the web UI should access the files using a signed URL from the S3-compatible object storage service, but the database should store the resource metadata and the resource files should be stored in the S3-compatible object storage service.

## 🧱 Implementation Tasks

-   [ ] Integrate MinIO with FastAPI using `aiobotocore` or `minio-py`
-   [ ] Create Pydantic models and DB models for:
    -   Wordlists
    -   Rule files
    -   Mask files
    -   Uploaded files
-   [ ] Add upload endpoints for each resource type
-   [ ] Implement resource listing with metadata and visibility filters
-   [ ] Add API access control to resources (sensitive vs. public)
-   [ ] Add hashed file validation to prevent duplicates
-   [ ] Create linking logic between attack definitions and resources
-   [ ] Implement auto-delete hooks when campaigns are deleted (if configured)

## 🔄 Backend Endpoints

-   POST /resources/wordlists
-   GET /resources/wordlists
-   POST /resources/rules
-   GET /resources/rules
-   POST /resources/masks
-   GET /resources/masks

## 🔒 Access Control

-   Admin: Full access
-   Power User: Can upload and delete
-   User: Can view non-sensitive resources and those assigned to projects
