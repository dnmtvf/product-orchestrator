#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from fastmcp import FastMCP

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from claude_agents_lib import (  # noqa: E402
    ClaudeAgentSyncError,
    ClaudeInvocationError,
    mapping_for_role,
    render_expected_agents,
    resolve_runtime_paths,
    run_claude_agent,
    sync_agents,
)


APP = FastMCP(
    name="claude-code",
    instructions="Repo-owned Claude Code MCP wrapper for PM orchestrator role prompts.",
)


def role_listing() -> list[dict[str, str]]:
    paths = resolve_runtime_paths(Path(__file__))
    sync_agents(paths, check=False)
    expected = render_expected_agents(paths)
    return [
        {
            "role": role,
            "agent_name": item["agent_name"],
            "prompt_path": item["prompt_path"],
            "output_path": item["relative_output_path"],
            "description": item["description"],
        }
        for role, item in sorted(expected.items())
    ]


@APP.tool(
    name="run_role_prompt",
    description="Run a prompt through the repo-owned Claude project agent mapped from a PM orchestrator role.",
)
def run_role_prompt(
    prompt: str,
    agent_role: str,
    agent_type: str | None = None,
    session_id: str | None = None,
    cwd: str | None = None,
) -> dict[str, object]:
    try:
        return run_claude_agent(
            Path(__file__),
            role=agent_role,
            prompt=prompt,
            session_id=session_id,
            cwd=cwd,
            agent_type=agent_type,
        )
    except (ClaudeAgentSyncError, ClaudeInvocationError) as exc:
        raise RuntimeError(str(exc)) from exc


@APP.tool(
    name="list_role_agents",
    description="List the repo-owned Claude project agents generated for PM orchestrator roles.",
)
def list_role_agents() -> list[dict[str, str]]:
    return role_listing()


def cli_run_agent(args: argparse.Namespace) -> int:
    try:
        result = run_claude_agent(
            Path(__file__),
            role=args.role,
            prompt=args.prompt,
            session_id=args.session_id,
            cwd=args.cwd,
            agent_type=args.agent_type,
        )
    except (ClaudeAgentSyncError, ClaudeInvocationError) as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(result["response"])
    return 0


def cli_list_role_agents(args: argparse.Namespace) -> int:
    del args
    try:
        print(json.dumps(role_listing(), indent=2, sort_keys=True))
    except ClaudeAgentSyncError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


def cli_resolve_role(args: argparse.Namespace) -> int:
    try:
        paths = resolve_runtime_paths(Path(__file__))
        sync_agents(paths, check=False)
        mapping = dict(mapping_for_role(paths, args.role))
        mapping["output_path"] = str(mapping["output_path"])
        print(json.dumps(mapping, indent=2, sort_keys=True))
    except ClaudeAgentSyncError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Repo-owned Claude Code MCP wrapper for the PM orchestrator.")
    subparsers = parser.add_subparsers(dest="command")

    run_parser = subparsers.add_parser("run-agent", help="Run a prompt through the mapped Claude project agent for a role.")
    run_parser.add_argument("--role", required=True)
    run_parser.add_argument("--prompt", required=True)
    run_parser.add_argument("--agent-type")
    run_parser.add_argument("--session-id")
    run_parser.add_argument("--cwd")
    run_parser.add_argument("--json", action="store_true")
    run_parser.set_defaults(func=cli_run_agent)

    list_parser = subparsers.add_parser("list-role-agents", help="Print the generated role-to-Claude-agent map.")
    list_parser.set_defaults(func=cli_list_role_agents)

    resolve_parser = subparsers.add_parser("resolve-role", help="Resolve a PM role to its generated Claude project agent.")
    resolve_parser.add_argument("--role", required=True)
    resolve_parser.set_defaults(func=cli_resolve_role)

    serve_parser = subparsers.add_parser("serve", help="Run the Claude Code MCP server over stdio.")
    serve_parser.set_defaults(func=None)

    args = parser.parse_args()
    if getattr(args, "func", None):
        return args.func(args)

    APP.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
