from __future__ import annotations

import ast
import inspect
from dataclasses import fields

from custom_content_studio.ui.route_shell import (
    BOUNDED_LAYOUT_POLICY,
    STANDALONE_ROUTES,
    BoundedLayoutPolicy,
    StandaloneRoute,
)


def test_catalog_declares_only_the_four_canonical_standalone_destinations() -> None:
    assert [(route.page_key, route.canonical_template) for route in STANDALONE_ROUTES] == [
        ("dashboard", "/dashboard"),
        ("projects", "/workspaces/{workspace_id}/projects"),
        ("content", "/workspaces/{workspace_id}/projects/{project_id}/contents"),
        ("assets", "/workspaces/{workspace_id}/assets"),
    ]
    assert len({route.page_key for route in STANDALONE_ROUTES}) == 4
    assert all(route.standalone for route in STANDALONE_ROUTES)


def test_catalog_is_immutable_declarative_data_without_runtime_surface() -> None:
    assert {field.name for field in fields(StandaloneRoute)} == {
        "page_key",
        "canonical_template",
        "standalone",
    }
    assert {field.name for field in fields(BoundedLayoutPolicy)} == {
        "header_in_viewport",
        "navigation_in_viewport",
        "current_action_context_in_viewport",
        "internal_work_area_count",
        "internal_work_area_may_scroll_or_paginate",
        "browser_document_long_form_scrolling_forbidden",
    }
    assert not [
        name
        for name, value in vars(StandaloneRoute).items()
        if not name.startswith("_") and callable(value)
    ]
    assert not [
        name
        for name, value in vars(BoundedLayoutPolicy).items()
        if not name.startswith("_") and callable(value)
    ]


def test_shared_layout_policy_keeps_one_bounded_work_area() -> None:
    assert BOUNDED_LAYOUT_POLICY.header_in_viewport
    assert BOUNDED_LAYOUT_POLICY.navigation_in_viewport
    assert BOUNDED_LAYOUT_POLICY.current_action_context_in_viewport
    assert BOUNDED_LAYOUT_POLICY.internal_work_area_count == 1
    assert BOUNDED_LAYOUT_POLICY.internal_work_area_may_scroll_or_paginate
    assert BOUNDED_LAYOUT_POLICY.browser_document_long_form_scrolling_forbidden


def test_route_shell_imports_only_declarative_standard_library_dependencies() -> None:
    tree = ast.parse(inspect.getsource(inspect.getmodule(StandaloneRoute)))
    imports = {
        alias.name.split(".")[0]
        for node in ast.walk(tree)
        if isinstance(node, ast.Import)
        for alias in node.names
    }
    imports.update(
        node.module.split(".")[0]
        for node in ast.walk(tree)
        if isinstance(node, ast.ImportFrom) and node.module is not None
    )

    assert imports <= {"__future__", "dataclasses"}


def test_route_shell_has_no_runtime_or_ui_behavior_names() -> None:
    tree = ast.parse(inspect.getsource(inspect.getmodule(StandaloneRoute)))

    assert not [node for node in ast.walk(tree) if isinstance(node, ast.FunctionDef)]
