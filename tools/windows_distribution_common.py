"""Headless process runner shared by Windows artifact builders."""
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str], cwd: Path, *, isolated: bool = False, timeout: int = 300) -> str:
    environment = os.environ.copy()
    if isolated:
        environment["PATH"] = os.pathsep.join([str(Path(environment["WINDIR"]) / "System32"), environment["WINDIR"]])
        environment.pop("PYTHONPATH", None)
        environment.pop("PYTHONHOME", None)
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    result = subprocess.run(command, cwd=cwd, env=environment, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=timeout,
                            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    output = result.stdout + result.stderr
    if result.returncode or re.search(r"(?m)^(?:SCRIPT ERROR:|ERROR:)", output):
        raise ValueError(f"Build/verification failed ({result.returncode}):\n{output[-10000:]}")
    return output
