#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from pathlib import Path

from claude_agents_lib import ClaudeAgentSyncError, resolve_runtime_paths, sync_agents


def main() -> int:
    parser = argparse.ArgumentParser(description="Sync repo-owned PM role prompts into project .claude/agents artifacts.")
    parser.add_argument("--check", action="store_true", help="Fail if any managed Claude agent file is missing or stale.")
    args = parser.parse_args()

    try:
        paths = resolve_runtime_paths(Path(__file__))
        result = sync_agents(paths, check=args.check)
    except ClaudeAgentSyncError as exc:
        print(f"CLAUDE_AGENT_SYNC|status=error|check={int(args.check)}|detail={exc}", file=sys.stderr)
        return 1

    for item in result["drift"]:
        status, relative_path = item.split(":", 1)
        print(f"CLAUDE_AGENT_DRIFT|status={status}|path={relative_path}", file=sys.stderr)

    status = "ok" if not result["drift"] else "drift"
    print(
        "CLAUDE_AGENT_SYNC|"
        f"status={status}|"
        f"check={int(args.check)}|"
        f"created={len(result['created'])}|"
        f"updated={len(result['updated'])}|"
        f"unchanged={len(result['unchanged'])}|"
        f"drift={len(result['drift'])}|"
        f"output_dir={paths.output_dir}"
    )
    return 0 if not result["drift"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
