import hashlib
from dataclasses import FrozenInstanceError
from datetime import UTC, datetime

import pytest

from custom_content_studio.domain import (
    ContentVersion,
    ContentVersionSnapshot,
    ContentVersionStatus,
    compute_snapshot_hash,
)


def test_snapshot_is_deeply_frozen_and_uses_registered_canonical_envelope() -> None:
    snapshot = ContentVersionSnapshot(
        title="Launch", script={"b": 2, "a": 1}, content={"published": False}
    )
    canonical = (
        '{"_schema":"ccs.content-version-snapshot","_version":1,'
        '"data":{"content":{"published":false},"script":{"a":1,"b":2},'
        '"title":"Launch"}}'
    )
    assert snapshot.canonical_json() == canonical
    assert snapshot.canonical_script_json() == '{"a":1,"b":2}'
    with pytest.raises(TypeError):
        snapshot.content["new"] = True  # type: ignore[index]


def test_snapshot_hash_has_exact_identity_preimage() -> None:
    snapshot = ContentVersionSnapshot(title="Launch", script=None, content={})
    preimage = (
        '{"content_id":"content-1","snapshot":'
        '{"_schema":"ccs.content-version-snapshot","_version":1,'
        '"data":{"content":{},"script":null,"title":"Launch"}},"version_number":1}'
    )
    assert (
        compute_snapshot_hash("content-1", 1, snapshot)
        == hashlib.sha256(preimage.encode("utf-8")).hexdigest()
    )
    assert compute_snapshot_hash("content-1", 2, snapshot) != compute_snapshot_hash(
        "content-1", 1, snapshot
    )


def test_content_version_is_frozen_and_validates_draft_identity() -> None:
    snapshot = ContentVersionSnapshot(title="Launch", script=None, content={})
    version = ContentVersion(
        version_id="version-1",
        content_id="content-1",
        version_number=1,
        parent_version_id=None,
        status=ContentVersionStatus.DRAFT,
        snapshot=snapshot,
        snapshot_hash=compute_snapshot_hash("content-1", 1, snapshot),
        created_by="user-1",
        created_at_utc=datetime(2026, 9, 9, tzinfo=UTC),
    )
    with pytest.raises(FrozenInstanceError):
        version.version_id = "replacement"  # type: ignore[misc]
    with pytest.raises(ValueError, match="positive integer"):
        ContentVersion(**{**version.__dict__, "version_number": 0})
