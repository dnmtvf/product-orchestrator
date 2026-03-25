#!/usr/bin/env python3
import json
import os
import queue
import shutil
import signal
import subprocess
import sys
import threading
import time
import uuid
from dataclasses import dataclass, field
from typing import Dict, List, Optional


PROTOCOL_VERSION = "2025-03-26"
SERVER_NAME = "pm-orchestrator/claude-code-mcp"
SERVER_VERSION = "1"


def compact(value: object) -> str:
    return " ".join(str(value or "").split()).strip()


def text_result(text: str, is_error: bool = False) -> Dict[str, object]:
    return {
        "content": [{"type": "text", "text": text}],
        "isError": is_error,
    }


def send(payload: Dict[str, object]) -> None:
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def tool_definition(name: str, description: str, properties: Dict[str, object], required: List[str]) -> Dict[str, object]:
    return {
        "name": name,
        "description": description,
        "inputSchema": {
            "type": "object",
            "properties": properties,
            "required": required,
            "additionalProperties": False,
        },
    }


AGENT_TOOL = tool_definition(
    "Agent",
    (
        "Launch a Claude task through the repo-owned PM wrapper. "
        "Supported launcher values are generic PM types (`default`, `explorer`, `worker`) "
        "plus native Claude aliases (`default`, `general-purpose`, `Explore`, `Plan`). "
        "Use `run_in_background=true` to start a background task and poll it with `TaskOutput`."
    ),
    {
        "description": {"type": "string"},
        "prompt": {"type": "string"},
        "subagent_type": {"type": "string"},
        "model": {"type": "string"},
        "name": {"type": "string"},
        "run_in_background": {"type": "boolean"},
        "mode": {"type": "string"},
        "team_name": {"type": "string"},
        "isolation": {"type": "string"},
    },
    ["description", "prompt"],
)

TASK_OUTPUT_TOOL = tool_definition(
    "TaskOutput",
    (
        "Read the output from a background Claude task started by the wrapper Agent tool. "
        "Use `block=true` to wait for completion up to `timeout` milliseconds."
    ),
    {
        "task_id": {"type": "string"},
        "block": {"type": "boolean"},
        "timeout": {"type": "integer", "minimum": 0},
    },
    ["task_id"],
)


def resolve_claude_bin() -> str:
    configured = os.environ.get("PM_CLAUDE_WRAPPER_REAL_BIN", "").strip()
    if configured:
      if os.path.isfile(configured) and os.access(configured, os.X_OK):
          return configured
      raise RuntimeError(f"PM_CLAUDE_WRAPPER_REAL_BIN is not executable: {configured}")

    discovered = shutil.which("claude")
    if discovered:
        return discovered
    raise RuntimeError("unable to resolve the real claude binary")


def map_agent(agent: str) -> str:
    normalized = (agent or "").strip()
    if not normalized:
        return "default"

    lower = normalized.lower()
    mapping = {
        "default": "default",
        "explorer": "Explore",
        "worker": "general-purpose",
        "general-purpose": "general-purpose",
        "generalpurpose": "general-purpose",
        "explore": "Explore",
        "plan": "Plan",
    }
    return mapping.get(lower, normalized)


def build_command(arguments: Dict[str, object]) -> List[str]:
    command = [resolve_claude_bin(), "-p", "--agent", map_agent(str(arguments.get("subagent_type", "default")))]
    model = compact(arguments.get("model"))
    name = compact(arguments.get("name"))
    if model:
        command.extend(["--model", model])
    if name:
        command.extend(["--name", name])
    command.append(str(arguments["prompt"]))
    return command


def summarize_process_output(stdout_text: str, stderr_text: str) -> str:
    stdout_text = (stdout_text or "").strip()
    stderr_text = (stderr_text or "").strip()
    return stdout_text if stdout_text else stderr_text


@dataclass
class BackgroundTask:
    task_id: str
    command: List[str]
    process: subprocess.Popen
    stdout_chunks: List[str] = field(default_factory=list)
    stderr_chunks: List[str] = field(default_factory=list)
    completed_at: Optional[float] = None
    stdout_thread: Optional[threading.Thread] = None
    stderr_thread: Optional[threading.Thread] = None

    def status(self) -> str:
        if self.process.poll() is None:
            return "running"
        return "complete" if self.process.returncode == 0 else "failed"

    def wait(self, timeout_seconds: Optional[float]) -> None:
        try:
            self.process.wait(timeout=timeout_seconds)
        except subprocess.TimeoutExpired:
            return
        self._mark_completed()

    def _mark_completed(self) -> None:
        if self.completed_at is None and self.process.poll() is not None:
            self.completed_at = time.time()

    def join_readers(self) -> None:
        if self.stdout_thread is not None:
            self.stdout_thread.join(timeout=0.1)
        if self.stderr_thread is not None:
            self.stderr_thread.join(timeout=0.1)
        self._mark_completed()

    def stdout_text(self) -> str:
        self.join_readers()
        return "".join(self.stdout_chunks)

    def stderr_text(self) -> str:
        self.join_readers()
        return "".join(self.stderr_chunks)


TASKS: Dict[str, BackgroundTask] = {}
TASKS_LOCK = threading.Lock()


def stream_reader(stream, chunks: List[str]) -> None:
    try:
        for line in iter(stream.readline, ""):
            if not line:
                break
            chunks.append(line)
    finally:
        try:
            stream.close()
        except Exception:
            pass


def start_background_task(command: List[str]) -> BackgroundTask:
    process = subprocess.Popen(
        command,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        bufsize=1,
    )
    task = BackgroundTask(task_id=f"claude-task-{uuid.uuid4().hex[:12]}", command=command, process=process)
    task.stdout_thread = threading.Thread(target=stream_reader, args=(process.stdout, task.stdout_chunks), daemon=True)
    task.stderr_thread = threading.Thread(target=stream_reader, args=(process.stderr, task.stderr_chunks), daemon=True)
    task.stdout_thread.start()
    task.stderr_thread.start()
    with TASKS_LOCK:
        TASKS[task.task_id] = task
    return task


def handle_agent(arguments: Dict[str, object]) -> Dict[str, object]:
    try:
        command = build_command(arguments)
    except Exception as exc:
        return text_result(compact(exc), is_error=True)

    if bool(arguments.get("run_in_background", False)):
        task = start_background_task(command)
        return text_result(f"Started background task {task.task_id}. Use TaskOutput with task_id={task.task_id}.")

    completed = subprocess.run(command, capture_output=True, text=True)
    output_text = summarize_process_output(completed.stdout, completed.stderr)
    if completed.returncode != 0:
        detail = output_text or f"Claude CLI exited with code {completed.returncode}."
        return text_result(detail, is_error=True)
    if not output_text:
        return text_result("Claude CLI completed without output.", is_error=True)
    return text_result(output_text)


def parse_timeout_ms(value: object, default_ms: int = 30000) -> int:
    if value is None:
        return default_ms
    try:
        timeout_ms = int(value)
    except Exception:
        return default_ms
    return timeout_ms if timeout_ms >= 0 else default_ms


def handle_task_output(arguments: Dict[str, object]) -> Dict[str, object]:
    task_id = compact(arguments.get("task_id"))
    if not task_id:
        return text_result("task_id is required.", is_error=True)

    with TASKS_LOCK:
        task = TASKS.get(task_id)
    if task is None:
        return text_result(f"Unknown task_id: {task_id}", is_error=True)

    should_block = bool(arguments.get("block", True))
    timeout_ms = parse_timeout_ms(arguments.get("timeout"))
    if should_block:
        task.wait(timeout_ms / 1000.0)

    status = task.status()
    stdout_text = task.stdout_text()
    stderr_text = task.stderr_text()
    output_text = summarize_process_output(stdout_text, stderr_text)

    if status == "running":
        if output_text:
            return text_result(f"Task {task_id} is still running.\n\n{output_text}")
        return text_result(f"Task {task_id} is still running.")

    if status == "failed":
        detail = output_text or f"Task {task_id} failed."
        return text_result(detail, is_error=True)

    return text_result(output_text or f"Task {task_id} completed.")


def main() -> int:
    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
        except Exception:
            continue

        method = request.get("method")
        request_id = request.get("id")

        if method == "initialize":
            send(
                {
                    "jsonrpc": "2.0",
                    "id": request_id,
                    "result": {
                        "protocolVersion": PROTOCOL_VERSION,
                        "capabilities": {"tools": {}},
                        "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
                    },
                }
            )
            continue

        if method == "notifications/initialized":
            continue

        if method == "tools/list":
            send({"jsonrpc": "2.0", "id": request_id, "result": {"tools": [AGENT_TOOL, TASK_OUTPUT_TOOL]}})
            continue

        if method == "tools/call":
            params = request.get("params", {})
            tool_name = params.get("name")
            arguments = params.get("arguments", {})
            if tool_name == "Agent":
                result = handle_agent(arguments)
            elif tool_name == "TaskOutput":
                result = handle_task_output(arguments)
            else:
                send(
                    {
                        "jsonrpc": "2.0",
                        "id": request_id,
                        "error": {"code": -32601, "message": f"Unknown tool: {tool_name}"},
                    }
                )
                continue

            send({"jsonrpc": "2.0", "id": request_id, "result": result})
            continue

        if request_id is not None:
            send({"jsonrpc": "2.0", "id": request_id, "error": {"code": -32601, "message": f"Unknown method: {method}"}})

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
