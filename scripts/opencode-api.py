#!/usr/bin/env python3
"""Bound OpenCode CLI requests and resolve status for explicitly bound sessions."""

import concurrent.futures
import json
import math
import os
import re
import signal
import subprocess
import sys
import time


def request(command, arguments, deadline):
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise TimeoutError("API deadline exceeded")
    # The tmux command option is trusted shell configuration, like @opencode_command.
    # Request arguments remain positional parameters, never interpolated shell text.

    process = subprocess.Popen(
        ["bash", "-c", command + ' "$@"', "opencode-api", *arguments],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        start_new_session=True,
    )
    try:
        stdout, stderr = process.communicate(timeout=remaining)

    except subprocess.TimeoutExpired:
        # Include wrapper children; killing only the shell can leave pipes open.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.communicate()
        raise TimeoutError("API deadline exceeded") from None
    if process.returncode:
        raise RuntimeError(
            stderr.decode(errors="replace").strip() or "API request failed"
        )
    return json.loads(stdout)


def valid_id(value):
    return (
        isinstance(value, str) and re.fullmatch(r"ses[a-zA-Z0-9_-]+", value) is not None
    )


def metadata(command, session_id, deadline):
    try:
        response = request(command, ["get", "/api/session/" + session_id], deadline)
        data = response.get("data") if isinstance(response, dict) else None
        if not isinstance(data, dict) or data.get("id") != session_id:
            return False, ""
        timestamp = (
            data.get("time", {}).get("updated")
            if isinstance(data.get("time"), dict)
            else None
        )
        updated = ""
        if (
            type(timestamp) in (int, float)
            and math.isfinite(timestamp)
            and timestamp >= 0
        ):
            updated = str(int(timestamp))
        return True, updated
    except (OSError, ValueError, RuntimeError, TimeoutError):
        return False, ""


def statuses(command, deadline):
    bindings = [line.rstrip("\n").split("\t", 1) for line in sys.stdin]
    bindings = [(row[0], row[1] if len(row) == 2 else "") for row in bindings]
    ids = list(dict.fromkeys(sid for _, sid in bindings if valid_id(sid)))
    active = None
    details = {}

    if ids:
        # One snapshot for the entire refresh. A failed snapshot is never idle.
        try:
            response = request(command, ["get", "/api/session/active"], deadline)
            if isinstance(response, dict) and isinstance(response.get("data"), dict):
                active = response["data"]
        except (OSError, ValueError, RuntimeError, TimeoutError):
            pass
        if active is not None:
            # All workers share one deadline, including time spent waiting in the queue.
            with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
                results = pool.map(lambda sid: metadata(command, sid, deadline), ids)
                details = dict(zip(ids, results))

    for name, session_id in bindings:
        exists, updated = details.get(session_id, (False, ""))
        state = "unknown"
        if exists and active is not None:
            if session_id not in active:
                state = "idle"
            elif (
                isinstance(active[session_id], dict)
                and active[session_id].get("type") == "running"
            ):
                state = "busy"
        print("\t".join((name, state, session_id, updated)))


def main():
    try:
        timeout = float(sys.argv[1])

        if not math.isfinite(timeout) or timeout <= 0:
            raise ValueError("API timeout must be a positive number")
        command, mode = sys.argv[2:4]
        deadline = time.monotonic() + timeout

        if mode == "status":
            statuses(command, deadline)

        elif mode == "request":
            print(json.dumps(request(command, sys.argv[4:], deadline)))

        else:
            raise ValueError("Unknown API helper mode")
    except (OSError, ValueError, RuntimeError, TimeoutError) as error:
        print("tmux-opencode-session-manager: " + str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
