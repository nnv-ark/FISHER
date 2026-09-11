#!/usr/bin/env python3
"""Validate registry/adapters.json before it ships to every install.

A broken registry file is not a broken app — installs quietly keep working
with what they have — but it means selector fixes stop reaching them, which
is the whole point of the file. This catches that before it merges.

Checks: valid JSON array; required fields; known kind; unique ids; an
integer adapterVersion >= 1 (a versionless entry can never be updated);
and versions not below the bundled copy of the same source, since a lower
version would be ignored by installs that already carry the bundled one.

Usage: python3 registry/validate.py [path-to-registry.json]
"""

import json
import sys

KINDS = {"html", "jsonld", "nextdata"}
REQUIRED = ("id", "name", "searchURL")


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except FileNotFoundError:
        sys.exit(f"{path}: file not found")
    except json.JSONDecodeError as e:
        sys.exit(f"{path}: not valid JSON — {e}")


def main():
    registry_path = sys.argv[1] if len(sys.argv) > 1 else "registry/adapters.json"
    bundled_path = "FISHER/Resources/adapters.json"

    data = load(registry_path)
    if not isinstance(data, list):
        sys.exit(f"{registry_path}: top level must be an array of adapters")
    if not data:
        sys.exit(f"{registry_path}: empty array — the registry must carry at least one source")

    problems = []
    seen = {}
    for i, entry in enumerate(data):
        label = f"entry {i} ({(entry.get('id') if isinstance(entry, dict) else '?')!r})"
        if not isinstance(entry, dict):
            problems.append(f"entry {i}: not an object")
            continue
        for key in REQUIRED:
            if not isinstance(entry.get(key), str) or not entry[key].strip():
                problems.append(f"{label}: {key} must be a non-empty string")
        kind = entry.get("kind")
        if kind not in KINDS:
            problems.append(f"{label}: kind must be one of {sorted(KINDS)}, got {kind!r}")
        adapter_id = entry.get("id")
        if isinstance(adapter_id, str) and adapter_id:
            if adapter_id in seen:
                problems.append(f"{label}: duplicate id, first seen at entry {seen[adapter_id]}")
            else:
                seen[adapter_id] = i
        version = entry.get("adapterVersion")
        if not isinstance(version, int) or isinstance(version, bool) or version < 1:
            problems.append(f"{label}: adapterVersion must be an integer >= 1 "
                            f"— a versionless entry can never be updated")

    bundled = load(bundled_path)
    if isinstance(bundled, list):
        bundled_versions = {b.get("id"): b.get("adapterVersion")
                            for b in bundled if isinstance(b, dict)}
        for entry in data:
            if not isinstance(entry, dict):
                continue
            adapter_id, version = entry.get("id"), entry.get("adapterVersion")
            floor = bundled_versions.get(adapter_id)
            if (isinstance(adapter_id, str) and isinstance(version, int)
                    and isinstance(floor, int) and version < floor):
                problems.append(f"entry ({adapter_id!r}): version {version} is below the "
                                f"bundled version {floor} — installs carrying the bundled "
                                f"one would ignore this update")

    if problems:
        print(f"{registry_path}: {len(problems)} problem(s)")
        for problem in problems:
            print(f"  - {problem}")
        sys.exit(1)

    top = max((e.get("adapterVersion", 0) for e in data if isinstance(e, dict)), default=0)
    print(f"{registry_path}: OK — {len(data)} sources, versions up to {top}")


if __name__ == "__main__":
    main()
