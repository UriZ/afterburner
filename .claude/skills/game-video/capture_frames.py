#!/usr/bin/env python3
"""Paced frame grabber for capture-video.sh — the real time base of #116.

Replaces the old per-frame `nc | python3` pair (2 process spawns per frame,
~17.3 real fps ceiling) with one process for the whole run. That buys two
things:

1. **Pacing.** Frame i targets wall-clock `t0 + i/requested_fps` on an
   *absolute* schedule, so a slow or retried frame is absorbed instead of
   accumulating drift. Measuring the mean rate alone would fix average
   playback speed but leave the frames unevenly spaced in real time while the
   container asserts they are uniform.
2. **Measurement.** A monotonic stamp is taken the instant each reply lands,
   so the caller can encode at the rate that actually happened rather than the
   one that was requested.

Wire protocol (verified against mcp_bridge_game.gd at a65b9c8): one fresh TCP
connection per frame, send `{"cmd":"screenshot"}`, read a single JSON object
terminated by "\\n" — the server does NOT close the connection, so reading to
EOF would stall until the socket timeout. `image_base64` holds a PNG.

Prints one JSON object on stdout for the shell to consume; progress and
warnings go to stderr.
"""

import argparse
import base64
import json
import socket
import statistics
import sys
import time

REQUEST = b'{"cmd":"screenshot"}'
ATTEMPTS_PER_FRAME = 3
RETRY_PAUSE_S = 0.15
MAX_CONSECUTIVE_FAILS = 5
SOCKET_TIMEOUT_S = 5.0
RECV_CHUNK = 1 << 16

# Below this fraction of the requested rate the run is reported as slipped.
PACING_SLIP_FRACTION = 0.97


def grab(port: int) -> bytes:
    """One screenshot round-trip. Returns decoded PNG bytes, raises on failure."""
    with socket.create_connection(("127.0.0.1", port), timeout=SOCKET_TIMEOUT_S) as sock:
        sock.settimeout(SOCKET_TIMEOUT_S)
        sock.sendall(REQUEST)
        buf = bytearray()
        while b"\n" not in buf:
            chunk = sock.recv(RECV_CHUNK)
            if not chunk:
                raise ConnectionError("bridge closed the connection before sending a full reply")
            buf += chunk
    reply = json.loads(bytes(buf).split(b"\n", 1)[0].decode("utf-8"))
    if "image_base64" not in reply:
        raise ValueError("no image in reply: %s" % reply.get("error", reply))
    return base64.b64decode(reply["image_base64"])


def capture(port: int, frames: int, fps: float, frame_dir: str) -> dict:
    stamps: list[float] = []
    captured = 0
    consecutive_fails = 0
    abort_reason = None

    started_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    t0 = time.monotonic()

    for i in range(frames):
        target = t0 + i / fps
        now = time.monotonic()
        if now < target:
            time.sleep(target - now)

        last_error = None
        png = None
        for attempt in range(ATTEMPTS_PER_FRAME):
            try:
                png = grab(port)
                break
            except Exception as exc:  # noqa: BLE001 — any failure is a retryable frame miss
                last_error = exc
                png = None
                if attempt < ATTEMPTS_PER_FRAME - 1:
                    time.sleep(RETRY_PAUSE_S)

        if png is not None:
            # Stamp on receipt, before the write, so disk latency is not counted
            # as inter-frame time.
            stamps.append(time.monotonic())
            captured += 1
            # Sequential naming with no gaps — ffmpeg's %04d pattern stops at the
            # first missing index. A short run fails loudly upstream anyway.
            with open("%s/frame_%04d.png" % (frame_dir, captured), "wb") as fh:
                fh.write(png)
            consecutive_fails = 0
        else:
            consecutive_fails += 1
            print(
                "  WARNING: frame %d/%d failed after %d attempts (%s)"
                % (i + 1, frames, ATTEMPTS_PER_FRAME, last_error),
                file=sys.stderr,
            )
            if consecutive_fails >= MAX_CONSECUTIVE_FAILS:
                abort_reason = (
                    "%d consecutive frame failures — bridge on port %d appears unresponsive"
                    % (MAX_CONSECUTIVE_FAILS, port)
                )
                print("ERROR: %s." % abort_reason, file=sys.stderr)
                break

        if (i + 1) % 10 == 0 or i + 1 == frames:
            print("  ... %d/%d attempted, %d captured" % (i + 1, frames, captured), file=sys.stderr)

    result = {
        "captured": captured,
        "requested_frames": frames,
        "requested_fps": round(float(fps), 3),
        "paced": True,
        "captured_utc": started_utc,
        "abort_reason": abort_reason,
    }

    # n-1 intervals, not n: dividing n by elapsed overstates the rate by
    # 1/(n-1) — 0.7% at 150 frames, 3.4% at 30.
    if len(stamps) >= 2:
        intervals = [stamps[i + 1] - stamps[i] for i in range(len(stamps) - 1)]
        wall_elapsed = stamps[-1] - stamps[0]
        measured_fps = (len(stamps) - 1) / wall_elapsed if wall_elapsed > 0 else 0.0
        result.update(
            {
                "wall_elapsed_s": round(wall_elapsed, 4),
                "measured_fps": round(measured_fps, 3),
                "interval_mean_s": round(statistics.fmean(intervals), 4),
                "interval_stdev_s": round(
                    statistics.stdev(intervals) if len(intervals) >= 2 else 0.0, 4
                ),
                "interval_max_s": round(max(intervals), 4),
                "pacing_slip": measured_fps < fps * PACING_SLIP_FRACTION,
            }
        )

    return result


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--port", type=int, required=True)
    ap.add_argument("--frames", type=int, required=True)
    ap.add_argument("--fps", type=float, required=True)
    ap.add_argument("--dir", required=True, help="directory to write frame_NNNN.png into")
    args = ap.parse_args()

    if args.fps <= 0:
        print("ERROR: --fps must be > 0", file=sys.stderr)
        return 2
    if args.frames < 1:
        print("ERROR: --frames must be >= 1", file=sys.stderr)
        return 2

    result = capture(args.port, args.frames, args.fps, args.dir)
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
