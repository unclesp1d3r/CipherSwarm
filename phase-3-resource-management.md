# Phase 3: Resource Management

CipherSwarm relies on MinIO for all static resource distribution (wordlists, rules, masks, charsets). This system must operate entirely on an **airgapped lab network** and serve **two cracking nodes** connected via 25GbE. All resource access must be secure, logged, and optimized for bandwidth efficiency.

---

## 🗂️ MinIO Integration

### Bucket Structure

-   [ ] `wordlists/` — Common dictionaries
-   [ ] `rules/` — Hashcat rule files
-   [ ] `masks/` — Mask pattern definitions
-   [ ] `charsets/` — Custom charset files
-   [ ] `temp/` — Staging area for new uploads

### Resource Model

Define a unified `Resource` model:

```python
class Resource(Base):
    id: UUID
    name: str
    original_filename: str
    description: Optional[str]
    size: int
    checksum: str  # MD5
    upload_date: datetime
    type: Enum("wordlist", "rule", "mask", "charset")
    tags: List[str]
    version: int
```

### Resource Management System

-   [ ] Upload form (drag/drop, progress bar)
-   [ ] Filename validation + duplicate detection
-   [ ] MD5 checksum calculation
-   [ ] Preview for text-based files (first N lines)
-   [ ] Resource tagging + filtering UI
-   [ ] Admin-only cleanup tools
-   [ ] Automatic versioning on re-upload

---

## 🔄 Resource Distribution

### Presigned URL Management

-   [ ] Generate presigned URLs for agents

    -   TTL: 15 minutes
    -   Bound to agent token + resource UUID
    -   Headers required: `Authorization`, `User-Agent`

-   [ ] Endpoint: `GET /api/v1/client/resources/{id}/download`

    -   Validates resource ownership + token match
    -   Logs download request (timestamp, agent_id, IP)

-   [ ] Optional: include filename hash in URL to allow caching with integrity

### Access Control & Security

-   [ ] Role-based access (admin, operator)
-   [ ] Signed URL revocation (if agent is disabled)
-   [ ] Rate limiting (Redis counter by agent_id)
-   [ ] URL access log table
-   [ ] Optional: File type validation + extension checking

---

## ⚡ Caching System

### Local Agent Cache

-   [ ] Agents cache resources to disk by UUID
-   [ ] Hash validation before task start
-   [ ] TTL defined in config (default: 48 hours)
-   [ ] Failed hash check triggers redownload

### Server-Side Redis Cache

-   [ ] Store metadata: file size, download count, last accessed
-   [ ] Cache busting on resource update
-   [ ] Used for stats dashboard and analytics

---

## 🧠 Notes for Cursor

-   All resource uploads must be stored using UUID-based filenames to prevent conflicts
-   Agent downloads must be validated with both checksum and access token
-   Use `minio-py` or `boto3` for signed URL generation — wrapped in async where possible
-   All access attempts must be logged, even if denied
-   Expect MinIO to be local to the network — no internet access
-   Build all logic assuming 25GbE but no upstream cloud fallback

