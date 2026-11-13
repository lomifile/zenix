from __future__ import annotations

import json
from dataclasses import dataclass


@dataclass(frozen=True)
class Monitor:
    name: str
    description: str = ""
    disabled: bool = False
    scale: float = 1.0


def parse_monitors(raw: str | None) -> list[Monitor]:
    if not raw:
        return []
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return []
    return [
        Monitor(
            name=m.get("name", ""),
            description=m.get("description", ""),
            disabled=bool(m.get("disabled", False)),
            scale=float(m.get("scale", 1.0)),
        )
        for m in data
        if isinstance(m, dict) and m.get("name")
    ]


def _override(monitor: Monitor, overrides: dict) -> dict:
    if monitor.name in overrides:
        return overrides[monitor.name]
    for key, value in overrides.items():
        if key and monitor.description.startswith(key):
            return value
    return {}


def _enabled_rule(monitor: Monitor, cfg: dict) -> dict:
    rule = {
        "output": monitor.name,
        "mode": "preferred",
        "position": "auto",
        "scale": cfg.get("scale", "auto"),
    }
    rule.update(_override(monitor, cfg.get("monitors") or {}))
    rule["output"] = monitor.name
    return rule


def plan_layout(monitors: list[Monitor], cfg: dict) -> list[dict]:
    laptop_name = cfg.get("laptop", "eDP-1")
    laptops = [m for m in monitors if m.name == laptop_name]
    externals = [m for m in monitors if m.name != laptop_name]

    enables = [_enabled_rule(m, cfg) for m in externals]
    disables = []
    for laptop in laptops:
        if externals and cfg.get("laptop_when_docked", "off") != "on":
            disables.append({"output": laptop.name, "disabled": True})
        else:
            enables.append(_enabled_rule(laptop, cfg))
    return enables + disables


def pending(rules: list[dict], monitors: list[Monitor], *, force: bool) -> list[dict]:
    current = {m.name: m for m in monitors}
    out = []
    for rule in rules:
        monitor = current.get(rule["output"])
        if monitor is None:
            continue
        if rule.get("disabled"):
            if not monitor.disabled:
                out.append(rule)
            continue
        scale = rule.get("scale")
        scale_differs = isinstance(scale, (int, float)) and abs(float(scale) - monitor.scale) > 1e-3
        if force or monitor.disabled or scale_differs:
            out.append(rule)
    return out


def _lua_value(value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(value)
    return json.dumps(str(value))


def _lua_table(rule: dict) -> str:
    fields = ", ".join(f"{key} = {_lua_value(value)}" for key, value in rule.items())
    return "{ " + fields + " }"


def to_lua(rule: dict) -> str:
    return f"hl.monitor({_lua_table(rule)})"


def saved_lua(rules: list[dict], laptop: str) -> str:
    body = "".join(f"\t\t{_lua_table(rule)},\n" for rule in rules)
    return f"return {{\n\tlaptop = {_lua_value(laptop)},\n\trules = {{\n{body}\t}},\n}}\n"
