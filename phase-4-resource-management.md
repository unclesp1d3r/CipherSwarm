# Phase 4: Resource Management

This phase adds robust support for file-based resource uploads and management within CipherSwarm. These resources include wordlists, rule files, mask files, and other artifacts required for hashcat operations.

This phase assumes that the web UI has been scaffolded in Phase 3 and will provide interfaces to manage these resources.

## ✅ Goals

- Implement backend file handling and metadata storage
- Integrate S3-compatible MinIO storage service
- Enable resource visibility, sensitivity tagging, and access control
- Provide API endpoints and UI backend logic to manage uploads/downloads

## 🧱 Implementation Tasks

- [ ] Integrate MinIO with FastAPI using `aiobotocore` or `minio-py`
- [ ] Create Pydantic models and DB models for:
  - Wordlists
  - Rule files
  - Mask files
  - Uploaded files
- [ ] Add upload endpoints for each resource type
- [ ] Implement resource listing with metadata and visibility filters
- [ ] Add API access control to resources (sensitive vs. public)
- [ ] Add hashed file validation to prevent duplicates
- [ ] Create linking logic between attack definitions and resources
- [ ] Implement auto-delete hooks when campaigns are deleted (if configured)

## 🔄 Backend Endpoints

- POST /resources/wordlists
- GET /resources/wordlists
- POST /resources/rules
- GET /resources/rules
- POST /resources/masks
- GET /resources/masks

## 🔒 Access Control

- Admin: Full access
- Power User: Can upload and delete
- User: Can view non-sensitive resources and those assigned to projects
