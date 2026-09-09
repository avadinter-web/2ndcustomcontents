"""Pure declarations for the first standalone Custom Content Studio routes."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class StandaloneRoute:
    """A canonical destination that a future UI runtime may render."""

    page_key: str
    canonical_template: str
    standalone: bool = True


@dataclass(frozen=True, slots=True)
class BoundedLayoutPolicy:
    """Viewport rule for a future standalone page renderer."""

    header_in_viewport: bool = True
    navigation_in_viewport: bool = True
    current_action_context_in_viewport: bool = True
    internal_work_area_count: int = 1
    internal_work_area_may_scroll_or_paginate: bool = True
    browser_document_long_form_scrolling_forbidden: bool = True


STANDALONE_ROUTES: tuple[StandaloneRoute, ...] = (
    StandaloneRoute(page_key="dashboard", canonical_template="/dashboard"),
    StandaloneRoute(
        page_key="projects",
        canonical_template="/workspaces/{workspace_id}/projects",
    ),
    StandaloneRoute(
        page_key="content",
        canonical_template="/workspaces/{workspace_id}/projects/{project_id}/contents",
    ),
    StandaloneRoute(page_key="assets", canonical_template="/workspaces/{workspace_id}/assets"),
)

BOUNDED_LAYOUT_POLICY = BoundedLayoutPolicy()


__all__ = [
    "BOUNDED_LAYOUT_POLICY",
    "STANDALONE_ROUTES",
    "BoundedLayoutPolicy",
    "StandaloneRoute",
]
