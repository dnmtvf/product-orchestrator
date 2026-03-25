#!/usr/bin/env python3
from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path

from fastmcp import Client
from fastmcp.client.transports import StdioTransport


ROOT_DIR = Path(__file__).resolve().parent.parent
WRAPPER = Path(
    os.environ.get(
        "CLAUDE_CODE_WRAPPER",
        str(ROOT_DIR / "skills" / "pm" / "scripts" / "claude-code-mcp"),
    )
).expanduser()
TRANSPORT_CWD = Path(os.environ.get("TEST_REPO_CWD", str(ROOT_DIR))).expanduser()
TOKEN = "CLAUDE_AGENT_MCP_SMOKE_OK"
PROMPT = (
    "This is an MCP smoke verification. Follow your normal output contract. "
    "Set Current phase to MCP SMOKE TEST. Put the exact token "
    f"{TOKEN} in Phase Error Summary and do not use it anywhere else."
)


def fail(message: str) -> int:
    print(f"[test-claude-agent-mcp-smoke] FAIL: {message}", file=sys.stderr)
    return 1


async def main() -> int:
    transport = StdioTransport(command=str(WRAPPER), args=[], cwd=str(TRANSPORT_CWD))
    async with Client(transport) as client:
        tools = await client.list_tools()
        tool_names = sorted(tool.name for tool in tools)
        if "run_role_prompt" not in tool_names or "list_role_agents" not in tool_names:
            return fail(f"missing expected MCP tools: {tool_names}")

        result = await client.call_tool(
            "run_role_prompt",
            {
                "agent_role": "project_manager",
                "prompt": PROMPT,
            },
        )
        data = getattr(result, "data", None) or getattr(result, "structured_content", None)
        if not isinstance(data, dict):
            return fail(f"unexpected MCP payload: {result!r}")

        response = str(data.get("response", ""))
        if TOKEN not in response:
            return fail(f"missing verification token in Claude response: {response!r}")
        if "Current phase" not in response:
            return fail(f"response did not preserve PM output contract: {response!r}")

        print(
            "[test-claude-agent-mcp-smoke] PASS: "
            f"agent={data.get('agent_name')} role={data.get('role')} token={TOKEN}"
        )
        return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
