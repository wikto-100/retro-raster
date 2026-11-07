#!/usr/bin/env python3
"""Reject CDC findings except the individually reviewed reset-bridge paths."""
from pathlib import Path
import sys


def check(path):
    # See docs/pixel-checkpoint.md. These are reset requests entering two-flop
    # bridges, not data crossings. Keep the exact endpoints visible in reports.
    reviewed = set()
    for dest in (
        "transmitter/core/LockLostReset/SyncAsyncx/oSyncStages_reg[0]/PRE",
        "transmitter/core/ClockGenInternal.ClockGenX/LockLostReset/SyncAsyncx/oSyncStages_reg[0]/PRE",
        "video_reset_sync_reg[0]/PRE",
        "receiver/core/TMDS_ClockingX/LockLostReset/SyncAsyncx/oSyncStages_reg[0]/PRE",
    ):
        reviewed.add(("CDC-10", "connected_reg/C", dest))
    locked_source = "receiver/core/TMDS_ClockingX/aLocked_reg/C"
    for dest in (
        "receiver/core/LockLostReset/SyncAsyncx/oSyncStages_reg[0]/PRE",
        "receiver/core/LockedSync/SyncAsyncx/oSyncStages_reg[0]/CLR",
    ):
        reviewed.add(("CDC-11", locked_source, dest))
    for channel in range(3):
        reviewed.add((
            "CDC-11", "receiver/core/LockLostReset/SyncAsyncx/oSyncStages_reg[1]/C",
            f"receiver/core/DataDecoders[{channel}].DecoderX/SyncBaseOvf/SourceReset/SyncAsyncx/oSyncStages_reg[0]/PRE",
        ))
    text = Path(path).read_text()
    if "Source Clock:" not in text or "CDC Report" not in text:
        raise RuntimeError("Expected a detailed CDC report, not a summary/empty file")
    count = 0
    for line in text.splitlines():
        fields = line.split()
        if len(fields) > 5 and fields[0].isdigit() and fields[2] in ("Critical", "Warning"):
            finding = (fields[1], fields[-2], fields[-1])
            if fields[-1].startswith(("diagnostics/snapshot_reg[", "diagnostics_video/snapshot_reg[")):
                # Read-only asynchronous diagnostic capture, never control/data.
                continue
            if finding not in reviewed:
                raise RuntimeError(f"Unreviewed clock crossing: {line.strip()}")
            count += 1
    print(f"Filter CDC check passed: {count} individually reviewed reset-bridge findings; no unreviewed warnings/critical paths")


if __name__ == "__main__":
    try:
        check(sys.argv[1])
    except (OSError, RuntimeError, IndexError) as error:
        sys.exit(f"ERROR: {error}")
