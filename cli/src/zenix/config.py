from __future__ import annotations

import json
from pathlib import Path

from zenix.console import die

LOCAL_RELPATH = Path(".config") / "zenix" / "config.json"


def local_path() -> Path:
    return Path.home() / LOCAL_RELPATH


def deep_merge(base: dict, over: dict) -> dict:
    merged = dict(base)
    for key, value in over.items():
        if isinstance(value, dict) and isinstance(merged.get(key), dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def read_json(path: Path) -> dict:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as exc:
        die(f"{path}: invalid JSON: {exc}")
    if not isinstance(data, dict):
        die(f"{path}: expected a JSON object at the top level")
    return data


def dump_json(data: dict) -> str:
    return json.dumps(data, indent=2, ensure_ascii=False) + "\n"


def lookup(data: dict, dotted: str):
    node = data
    for part in dotted.split("."):
        if not isinstance(node, dict) or part not in node:
            return None
        node = node[part]
    return node


def assign(data: dict, dotted: str, value) -> dict:
    out = json.loads(json.dumps(data))
    node = out
    parts = dotted.split(".")
    for part in parts[:-1]:
        child = node.get(part)
        if not isinstance(child, dict):
            child = {}
            node[part] = child
        node = child
    node[parts[-1]] = value
    return out


def parse_value(raw: str):
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return raw


class Config:
    def __init__(self, repo_path: Path, local: Path, shared: dict, machine: dict) -> None:
        self.repo_path = repo_path
        self.local_path = local
        self.shared = shared
        self.machine = machine
        self.data = deep_merge(shared, machine)

    @classmethod
    def load(cls, repo) -> "Config":
        local = local_path()
        return cls(repo.zenix_json, local, read_json(repo.zenix_json), read_json(local))

    def get(self, dotted: str, default=None):
        value = lookup(self.data, dotted)
        return default if value is None else value

    def source(self, dotted: str) -> str | None:
        if lookup(self.machine, dotted) is not None:
            return "local"
        if lookup(self.shared, dotted) is not None:
            return "repo"
        return None

    def set(self, ctx, dotted: str, value, *, local: bool = False) -> Path:
        if local:
            self.machine = assign(self.machine, dotted, value)
            target, data = self.local_path, self.machine
        else:
            self.shared = assign(self.shared, dotted, value)
            target, data = self.repo_path, self.shared
        self.data = deep_merge(self.shared, self.machine)
        ctx.write(target, dump_json(data))
        return target
