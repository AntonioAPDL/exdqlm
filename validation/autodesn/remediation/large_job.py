"""Prevent concurrent large R/Julia jobs after the observed full-bank OOM.

This is a nonblocking process-held lock, not a queue or a background scheduler.
Small reference/calibration cases remain independently schedulable.
"""
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import json
import os

@contextmanager
def single_large_job(root, role):
    path=root/'artifacts/large_job.lock'
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('a+') as handle:
        try:
            fcntl.flock(handle.fileno(),fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            handle.seek(0)
            raise RuntimeError('Another observed large job holds the memory reservation: '+handle.read()) from None
        handle.seek(0);handle.truncate()
        json.dump(dict(pid=os.getpid(),role=role,started_utc=datetime.now(timezone.utc).isoformat()),handle)
        handle.flush();os.fsync(handle.fileno())
        try:yield
        finally:fcntl.flock(handle.fileno(),fcntl.LOCK_UN)
