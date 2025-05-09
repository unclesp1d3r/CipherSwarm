#!/usr/bin/env python3
# /// script
# requires-python = ">=3.13"
# dependencies = [
#     "pydantic",
#     "sqlalchemy",
# ]
# ///


# scripts/dev/check_schema_types.py
import importlib
import inspect
import sys
from typing import Any

from pydantic import BaseModel
from sqlalchemy.orm import DeclarativeMeta

# Modify this if needed
MODEL_PATH = "app.models"
SCHEMA_PATH = "app.schemas"


def get_classes_from_module(module_path: str) -> dict[str, type[Any]]:
    module = importlib.import_module(module_path)
    return {
        name: cls for name, cls in inspect.getmembers(module) if inspect.isclass(cls)
    }


def main() -> None:
    models = get_classes_from_module(MODEL_PATH)
    schemas = get_classes_from_module(SCHEMA_PATH)

    mismatches = []

    for name, model_cls in models.items():
        if not isinstance(model_cls, DeclarativeMeta):
            continue
        schema_cls = schemas.get(name + "Create") or schemas.get(name + "Base")
        if not schema_cls or not issubclass(schema_cls, BaseModel):
            continue

        for field in schema_cls.__annotations__:
            model_field = getattr(model_cls, field, None)
            if model_field is not None and hasattr(model_field, "type"):
                schema_type = schema_cls.__annotations__[field]
                model_type = type(model_field.type).__name__
                if model_type not in str(schema_type):
                    mismatches.append((name, field, model_type, schema_type))

    if mismatches:
        print("⚠️ Detected potential mismatches:")
        for model, field, model_type, schema_type in mismatches:
            print(f" - {model}.{field}: model={model_type} vs schema={schema_type}")
        sys.exit(1)
    else:
        print("✅ No mismatches found.")


if __name__ == "__main__":
    main()
