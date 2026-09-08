# CCS-02-009 Editable Text Safety Discovery

Status: DISCOVERY COMPLETE / SUCCESSOR AND NARROW CHANGE CONTROL REQUIRED / IMPLEMENTATION NOT AUTHORIZED
Date: 2026-09-09
Repository baseline: $(@{_schema=ccs.orchestration.task-registry; _version=1; context=; implementation_authorized=False; normalization=; readiness=; registry_digest=d6580809fa1604051336c93c454f760a5808030ab553750e016fc41f1e81508a; registry_id=vc01b-local-20260907-r19; registry_kind=RUNTIME_NORMALIZED; registry_status=DRAFT; tasks=System.Object[]}.context.repository.current_commit)
Registry inspected: vc01b-local-20260907-r19
Canonical task: CCS-02-009 - String normalization: review_note and editable text safety

## Decision

eview_note and other editable notes are already specified as str | None, but the existing
language does not define a safe, lossless boundary. CCS-02-009 is the smallest shared domain
policy, not a review aggregate or persistence feature. Its correct parent is **IMP-022** because
it is a dependency-free Content-side value policy, following CCS-02-008. CCS-07 remains the future
consumer that chooses ReviewSession fields, persistence, lifecycle, authorization, and UI behavior.

The candidate API is custom_content_studio.domain.editable_text.normalize_editable_text(value).
It accepts only str | None; None remains absence and "" remains a present empty value. A valid
string is returned byte-for-code-point unchanged: no trim, casefold, whitespace collapse, escaping,
line-ending conversion, or NFC/NFD/NFKC/NFKD conversion occurs. len(value) is the binding length
measure and must be at most 10,000 Python code points. U+000A LF, U+000D CR, and an existing CRLF
pair are allowed and preserved exactly. Every other Unicode General Category Cc control character
is rejected; lone surrogate code points are also rejected because they are not Unicode scalar values.

This leaf does not introduce review persistence, a ReviewSession field, a schema/migration, API/UI,
repository/service, Content or ContentVersion mutation, sanitization/rendering, or any CCS-07
consumer change. A later consumer may impose its own narrower display or storage constraint only at
its own boundary; it must not reinterpret this policy as permission to transform accepted text.
