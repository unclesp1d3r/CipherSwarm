Here's a Skirmish-style implementation checklist for the Crackable Upload Processing Pipeline:

### 📦 Crackable Upload Plugin Pipeline — Skirmish Task Checklist

Review `📂 Crackable Uploads` section in `docs/v2_rewrite_implementation_plan/phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md` for the complete desciption of the crackable uploads pipeline and the high level tasks that need to be completed. The tasks below are a more detailed breakdown of the tasks that need to be completed before the crackable uploads pipeline can be implemented.

#### 🔧 Backend Models & DB

- [x] Create `HashUploadTask` model:
  - Fields: `id`, `user_id`, `filename`, `status`, `started_at`, `finished_at`, `error_count`, `hash_list_id`, `campaign_id`
- [x] Create `UploadErrorEntry` model:
  - Fields: `id`, `upload_id`, `line_number`, `raw_line`, `error_message`
- [x] Add Alembic migrations for both models

#### 🗂️ File Handling + Storage

- [x] Create a new `UploadResourceFile` model:
  - Similar to `AttackResourceFile` except this is for the purpose of uploading a file or text blob to the bucket and then only downloaded by the processing task
  - It might be possible to use a subclass of `AttackResourceFile` to avoid duplicating code, have a specific variant of the `AttackResourceFile` model only for uploads, or to have them share a common base class. The big difference is that the `UploadResourceFile` model is not used for any other purpose than to store the uploaded file and is not used for any other attack resources, so there's never a `line_format` field.
- [x] Return a presigned url to allow the user to upload a file or save the text blob in the `content` field of the `UploadResourceFile` model. This will require updates to `app/api/v1/endpoints/web/uploads.py`, `app/core/services/resource_service.py`, and `app/core/services/storage_service.py`. Triggering the upload will create a new `HashUploadTask` model and the `UploadResourceFile` model will be linked to the `HashUploadTask` model.
- [x] Create a new `RawHash` model:
  - Fields: `id: int`, `hash: str`, `hash_type: HashType`, `username: str`, `metadata: dict[str, str]`, `line_number: int`, `upload_error_entry_id: int | None`
  - This will be used to store the raw hashes extracted from the file.

#### 🪄 Plugin Interface & Dispatch

The logical pipeline for the crackable uploads plugin is as follows:
1. The user initiated the upload task, which creates a `HashUploadTask` model.
2. The user uploads a file or text blob to the system, which is stored in the `UploadResourceFile` model.
3. The file is downloaded by a background task to a temporary location and the `extract_hashes()` function is called on the appropriate plugin, based on the file extension selected during the creation of the `HashUploadTask`, to extract the hashes from the file. 
4. Each hash is extracted from the file and added to the `HashUploadTask` model a `raw_hashes` field, which is a list of `RawHash` objects, each containing the hash and the hash type, as identifed by the `HashGuessService`.
5. A new `Campaign` and `HashList` are created with `is_unavailable` set to `True`, and the `HashUploadTask` is linked to the `Campaign` and `HashList`.
6. The each hash in the `raw_hashes` field is then parsed and converted to the appropriate hashcat-compatible format using the `parse_hash_line()` function. The resulting formatted hash is added to the generated `HashList` model as a new `HashItem`, along with the `username` and `metadata` fields. The metadata field is a dictionary of key-value pairs that are extracted from the hash, and is defined by the plugin. If there are errors, the `UploadErrorEntry` model is created to store the error message and the line number of the hash that caused the error.
7. If all raw hashes are successfully parsed, the `HashList` and `Campaign` models are updated to reflect the status of the upload and processing, and the `HashUploadTask` is updated to reflect the status of the upload and processing. If there are no `UploadErrorEntry` objects and no unparsed hashes, the `UploadResourceFile` is marked for deletion. 
8. The user is notified of the status of the upload and processing. If there are no errors, the `Campaign` and `HashList` models are updated to set the `is_unavailable` field to `False` and the campaign status remains in `DRAFT`. If there are errors, the campaign status remains in `DRAFT` and the `HashList` and `Campaign` models are updated to set the `is_unavailable` field to `True`, allowing the user to edit the hash list and campaign to fix the errors.

- [x] Create `plugins/` folder with base interface:
  ```python
  def extract_hashes(path: Path) -> list[RawHash]: ...
  ```
- [x] 	Add `plugins/shadow_plugin.py` (first plugin implementation)
- [x] 	Add dispatcher:
    - Loads plugin based on extension (or selected by the user in the UI during the upload task creation)
    - Validates it implements `extract_hashes()`
- [x]  Raise and log `PluginExecutionError` exception if plugin fails
- [x]  Add tests for the plugin interface and dispatcher. The tests include verifying that the plugin is loaded and that the `extract_hashes()` function is implemented correctly. Use shadow_plugin.py as the reference plugin for the tests.

#### 🧠 Hash Parsing & Conversion
- [x] 	Implement 
    ```python
    parse_hash_line(raw_hash: RawHash) -> ParsedHashLine | None
    ```
	-	Validates format
	-	Extracts: `username: str | None`, `hashcat_hash: str`, `metadata: dict[str, str]`
- [ ] 	Add call to hash type guessing (use `HashGuessService` from `app.core.services.hash_guess_service`)
- [ ]	Enforce type confidence threshold before inserting
- [ ]   Create an initial reference plugin implementation to use for tests that supports the standard linux `shadow` file format using `sha512crypt` hashes. It should allow either a standard shadow file or a a combined "unshadowed" file generated by the `unshadow` tool (see [unshadow man page](https://manpages.ubuntu.com/manpages/noble/man8/unshadow.8.html) for reference). Every plugin should be a python file in the `plugins/` folder and should be a valid python module. The plugin file should have been created in the previou set of tasks, so it just needs to be updated to implement the `extract_hashes()` function, along with a set of tests to verify the plugin is working as expected.

#### 🛠️ HashList + Campaign Creation
- [ ]	Create ephemeral HashList:
	-	Make a `AttackResourceFile` with `resource_type` `AttackResourceType.EPHEMERAL_HASH_LIST`
	-	Add a flag to the hash list: `is_unavailable`
- [ ]	Create Campaign under current user's project
	-	Add a flag to the campaign: `is_unavailable`
- [ ]	Link both to `HashUploadTask`

#### 🔁 Task Runner + Status Updater
- [ ]	Create background task: 
    ```python
    process_uploaded_hash_file(upload_id: int)
    ```
- [ ]	Add status tracking:
	-	`pending` → `running` → `completed | partial_failure | failed`
- [ ]	Log failed lines to UploadErrorEntry
- [ ]	On success: mark hashlist/campaign as available

#### 🌐 API Endpoints
- [ ]	`POST /api/v1/web/uploads/`
    -	Accept file upload
    -	Triggers background task
- [ ]	`GET /api/v1/web/uploads/{id}/status`
    -	Returns:
    -	`status`, `started_at`, `finished_at`
	-	`error_count`
- [ ]	`GET /api/v1/web/uploads/{id}/errors` - Returns list of failed lines (paginated) (derive from `PaginatedResponse` in `app.schemas.shared`)

#### 🧪 Tests
- [ ]	Unit tests for plugin interface and dispatcher
- [ ]	Hash parser + inference tests (use `HashGuessService` from `app.core.services.hash_guess_service`)
- [ ]	Integration test: full upload flow with synthetic data
- [ ]	Permission test: Only allow upload for authenticated users

#### 🔐 Security & Hardening
- [ ]	Sanitize file names and restrict extensions (`shadow`, `.pdf`, `.zip`, `.7z`, `.docx`, etc.)
- [ ]	Set upload size limit (e.g., 100 MB)
- [ ]	Disable network access in plugins (plugin runner should be subprocess-isolated or use restricted Python execution)
- [ ]	Escape all user-visible error lines in UI

#### 🧩 UI Integration Prep
- [ ]	Define structure for status polling (`/api/v1/web/uploads/{id}/status`) - This should return the status of the upload task, including the hash type, extracted preview, and validation state. It should also return the ID of the uploaded resource file, along with an upload task ID that can be used to view the new upload processing progress in the UI. Status information and task completion information should be returned for each step of the upload and processing process to reflect the current state in the UI.
- [ ]	Ensure error lines are returned in full with line number + reason - This should be displayed in the UI when the `GET /api/v1/web/uploads/{id}/errors` endpoint is called. It should be a list of `UploadErrorEntry` objects that are paginated (derive from `PaginatedResponse` in `app.schemas.shared`)
- [ ]	Add status to Campaign and HashList models: `is_unavailable` - This should be used to indicate that the hash list and campaign are still being processed and are not ready to be used. This should default to `False` for new campaigns and hash lists, but should be set to `True` only when created by the crackable upload task and reverted to `False` when the processing is complete.
