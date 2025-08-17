"""
Unit tests for storage service.
"""

from typing import Any
from unittest.mock import MagicMock, patch

import pytest
from minio.error import S3Error

from app.core.services.storage_service import StorageService


@pytest.fixture
def mock_minio_client() -> Any:
    """Mock MinIO client for testing."""
    with patch("app.core.services.storage_service.Minio") as mock_minio:
        mock_client = MagicMock()
        mock_minio.return_value = mock_client
        yield mock_client


def test_storage_service_initialization_default_settings() -> None:
    """Test StorageService initialization with default settings."""
    with patch("app.core.services.storage_service.settings") as mock_settings:
        mock_settings.MINIO_ENDPOINT = "localhost:9000"
        mock_settings.MINIO_ACCESS_KEY = "test_access"
        mock_settings.MINIO_SECRET_KEY = "test_secret"
        mock_settings.MINIO_REGION = "us-east-1"

        service = StorageService()

        assert service.endpoint_url == "localhost:9000"
        assert service.access_key == "test_access"
        assert service.secret_key == "test_secret"
        assert service.region == "us-east-1"
        assert service.secure is False  # localhost doesn't start with https://


def test_storage_service_initialization_custom_settings() -> None:
    """Test StorageService initialization with custom settings."""
    service = StorageService(
        endpoint_url="https://s3.amazonaws.com",
        access_key="custom_access",
        secret_key="custom_secret",
        secure=True,
        region="eu-west-1",
    )

    assert service.endpoint_url == "https://s3.amazonaws.com"
    assert service.access_key == "custom_access"
    assert service.secret_key == "custom_secret"
    assert service.secure is True
    assert service.region == "eu-west-1"


def test_storage_service_secure_detection_https() -> None:
    """Test that secure is automatically detected from HTTPS URLs."""
    service = StorageService(endpoint_url="https://minio.example.com")
    assert service.secure is True


def test_storage_service_secure_detection_http() -> None:
    """Test that secure is automatically detected from HTTP URLs."""
    service = StorageService(endpoint_url="http://minio.example.com")
    assert service.secure is False


def test_storage_service_client_property_success(mock_minio_client: Any) -> None:
    """Test successful client property initialization."""
    # Mock successful connection
    mock_minio_client.list_buckets.return_value = []

    service = StorageService(
        endpoint_url="localhost:9000",
        access_key="test_access",
        secret_key="test_secret",
    )

    # Access client property
    client = service.client

    assert client is not None
    assert client == mock_minio_client
    mock_minio_client.list_buckets.assert_called_once()


def test_storage_service_client_property_connection_failure(
    mock_minio_client: Any,
) -> None:
    """Test client property with connection failure."""
    # Mock connection failure - S3Error expects (message, code, resource, request_id, host_id, response)
    from io import BytesIO

    from urllib3 import HTTPResponse

    mock_response = HTTPResponse(
        body=BytesIO(b""), status=403, headers={}, preload_content=False
    )
    mock_minio_client.list_buckets.side_effect = S3Error(
        "Connection failed",
        "NoSuchBucket",
        "test-resource",
        "request-123",
        "test-host-id",
        mock_response,
    )

    service = StorageService(
        endpoint_url="localhost:9000",
        access_key="test_access",
        secret_key="test_secret",
    )

    # Accessing client property should raise ConnectionError (which wraps S3Error)
    with pytest.raises(ConnectionError):
        _ = service.client


def test_storage_service_client_property_caching(mock_minio_client: Any) -> None:
    """Test that client property caches the MinIO client instance."""
    # Mock successful connection
    mock_minio_client.list_buckets.return_value = []

    service = StorageService(
        endpoint_url="localhost:9000",
        access_key="test_access",
        secret_key="test_secret",
    )

    # Access client property multiple times
    client1 = service.client
    client2 = service.client

    # Should return the same instance
    assert client1 is client2
    # list_buckets should only be called once during initialization
    mock_minio_client.list_buckets.assert_called_once()


@patch("app.core.services.storage_service.logger")
def test_storage_service_client_logging(
    mock_logger: Any, mock_minio_client: Any
) -> None:
    """Test that client initialization logs connection info."""
    # Mock successful connection
    mock_minio_client.list_buckets.return_value = []

    service = StorageService(
        endpoint_url="https://minio.example.com",
        access_key="test_access",
        secret_key="test_secret",
    )

    # Access client property to trigger initialization
    _ = service.client

    # Verify logging was called
    mock_logger.info.assert_called_once()
    log_call_args = mock_logger.info.call_args[0][0]
    assert "MinIO client initialized" in log_call_args
    assert "https://minio.example.com" in log_call_args
    assert "secure: True" in log_call_args


def test_storage_service_region_handling() -> None:
    """Test that region is handled correctly when None."""
    with patch("app.core.services.storage_service.settings") as mock_settings:
        mock_settings.MINIO_ENDPOINT = "localhost:9000"
        mock_settings.MINIO_ACCESS_KEY = "test_access"
        mock_settings.MINIO_SECRET_KEY = "test_secret"
        # Set MINIO_REGION to None as per settings default
        mock_settings.MINIO_REGION = None

        service = StorageService()

        # Should handle None region gracefully
        assert service.region is None


def test_storage_service_initialization_with_none_region() -> None:
    """Test StorageService initialization with explicit None region."""
    service = StorageService(
        endpoint_url="localhost:9000",
        access_key="test_access",
        secret_key="test_secret",
        region=None,
    )

    assert service.region is None


@patch("app.core.services.storage_service.Minio")
def test_storage_service_minio_initialization_parameters(mock_minio_class: Any) -> None:
    """Test that MinIO client is initialized with correct parameters."""
    mock_client = MagicMock()
    mock_client.list_buckets.return_value = []
    mock_minio_class.return_value = mock_client

    service = StorageService(
        endpoint_url="https://s3.amazonaws.com",
        access_key="test_access",
        secret_key="test_secret",
        secure=True,
        region="us-west-2",
    )

    # Access client to trigger initialization
    _ = service.client

    # Verify MinIO was called with correct parameters
    mock_minio_class.assert_called_once_with(
        "https://s3.amazonaws.com",
        access_key="test_access",
        secret_key="test_secret",
        secure=True,
        region="us-west-2",
    )
