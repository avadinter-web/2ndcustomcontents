"""Shared application composition and startup entrypoints."""

from .composition import bootstrap
from .startup import main

__all__ = ["bootstrap", "main"]
