"""Fail-closed checks for legacy TruckSim batch output."""
from pathlib import Path


def replace_once(text, old, new):
    count = text.count(old)
    if count != 1:
        raise ValueError(f'Expected exactly one parameter anchor, found {count}: {old[:80]!r}')
    return text.replace(old, new, 1)


def file_signature(path):
    try:
        stat = Path(path).stat()
    except FileNotFoundError:
        return None
    return (stat.st_mtime_ns, stat.st_size)


def validate_solver_output(returncode, path, before):
    if returncode != 0:
        raise RuntimeError(f'TruckSim solver returned {returncode}; no output accepted')
    after = file_signature(path)
    if after is None or after == before or after[1] == 0:
        raise RuntimeError(f'TruckSim output absent, empty, or not refreshed: {path}')
