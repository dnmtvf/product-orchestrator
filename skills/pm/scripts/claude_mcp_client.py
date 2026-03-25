#!/usr/bin/env python3
from __future__ import annotations

import argparse
import asyncio
import json
import os
import sys
import uuid
from pathlib import Path
from typing import Any

from fastmcp import Client
from fastmcp.client.transports import StdioTransport


def fail(message: str) -> int:
    print(message, file=sys.stderr)
    return 1


def parse_env_pair(raw: str) -> tuple[str, str]:
    if "=" not in raw:
        raise ValueError(f"Invalid --env entry (expected KEY=VALUE): {raw}")
    key, value = raw.split("=", 1)
    key = key.strip()
    if not key:
        raise ValueError(f"Invalid --env entry (empty key): {raw}")
    return key, value


def load_prompt(args: argparse.Namespace) -> str:
    if args.prompt:
        return args.prompt
    if not args.prompt_file:
        raise ValueError("Either --prompt or --prompt-file is required")
    prompt_path = Path(args.prompt_file).expanduser().resolve()
    if not prompt_path.is_file():
        raise ValueError(f"Prompt file not found: {prompt_path}")
    return prompt_path.read_text(encoding="utf-8")


def normalize_tool_payload(result: Any) -> dict[str, Any]:
    data = getattr(result, "data", None) or getattr(result, "structured_content", None)
    if not isinstance(data, dict):
        raise RuntimeError(f"Unexpected MCP payload: {result!r}")
    return data


def normalize_session_id(session_id: str | None) -> str | None:
    if not session_id:
        return None
    try:
        return str(uuid.UUID(session_id))
    except ValueError:
        # Claude requires a UUID-shaped session id. Use a deterministic mapping so
        # repeated wrapper session ids still continue the same underlying session.
        return str(uuid.uuid5(uuid.NAMESPACE_URL, f"pm-claude-wrapper:{session_id}"))


async def invoke_run_role_prompt(args: argparse.Namespace) -> dict[str, Any]:
    prompt = load_prompt(args)
    wrapper = Path(args.wrapper).expanduser().resolve()
    if not wrapper.is_file():
        raise ValueError(f"Wrapper command not found: {wrapper}")
    if not os.access(wrapper, os.X_OK):
        raise ValueError(f"Wrapper command is not executable: {wrapper}")

    cwd = Path(args.cwd).expanduser().resolve()
    if not cwd.is_dir():
        raise ValueError(f"Working directory not found: {cwd}")

    env = dict(os.environ)
    for raw_pair in args.env:
        key, value = parse_env_pair(raw_pair)
        env[key] = value

    transport = StdioTransport(
        command=str(wrapper),
        args=[],
        env=env,
        cwd=str(cwd),
    )
    timeout = float(args.timeout_seconds)

    async with Client(transport, timeout=timeout, init_timeout=timeout) as client:
        tools = await asyncio.wait_for(client.list_tools(), timeout=timeout)
        tool_names = sorted(tool.name for tool in tools)
        required_tools = {"run_role_prompt", "list_role_agents"}
        missing_tools = sorted(required_tools - set(tool_names))
        if missing_tools:
            raise RuntimeError(
                "Missing expected MCP tools: "
                + ",".join(missing_tools)
                + " from "
                + ",".join(tool_names)
            )

        request: dict[str, Any] = {
            "agent_role": args.agent_role,
            "prompt": prompt,
            "cwd": str(cwd),
        }
        normalized_session_id = normalize_session_id(args.session_id)
        if normalized_session_id:
            request["session_id"] = normalized_session_id
        if args.agent_type:
            request["agent_type"] = args.agent_type

        result = await asyncio.wait_for(client.call_tool("run_role_prompt", request), timeout=timeout)
        payload = normalize_tool_payload(result)
        payload["tool_names"] = tool_names
        payload["wrapper"] = str(wrapper)
        payload["cwd"] = str(cwd)
        if normalized_session_id:
            payload["claude_session_id"] = normalized_session_id
        return payload


def command_run_role_prompt(args: argparse.Namespace) -> int:
    try:
        payload = asyncio.run(invoke_run_role_prompt(args))
    except Exception as exc:  # pragma: no cover - surfaced through CLI tests/smoke
        return fail(str(exc))

    response = str(payload.get("response", ""))
    if args.response_file:
        response_path = Path(args.response_file).expanduser().resolve()
        response_path.parent.mkdir(parents=True, exist_ok=True)
        response_path.write_text(response, encoding="utf-8")
        payload["response_file"] = str(response_path)

    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Invoke the repo-owned claude-code MCP wrapper over stdio.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    run_parser = subparsers.add_parser("run-role-prompt", help="Call run_role_prompt through the configured wrapper.")
    prompt_group = run_parser.add_mutually_exclusive_group(required=True)
    prompt_group.add_argument("--prompt")
    prompt_group.add_argument("--prompt-file")
    run_parser.add_argument("--wrapper", required=True)
    run_parser.add_argument("--cwd", required=True)
    run_parser.add_argument("--agent-role", required=True)
    run_parser.add_argument("--agent-type")
    run_parser.add_argument("--session-id")
    run_parser.add_argument("--response-file")
    run_parser.add_argument("--timeout-seconds", type=float, default=30.0)
    run_parser.add_argument("--env", action="append", default=[], help="Extra env passed to the wrapper command (KEY=VALUE).")
    run_parser.set_defaults(func=command_run_role_prompt)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
