#!/usr/bin/env python3

from __future__ import annotations

import argparse
import subprocess
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

if __package__:
    from tools.ci.gmtl_lock import verify_gmtl_lock
else:
    from gmtl_lock import verify_gmtl_lock


def load_policy(root: Path) -> dict:
    return tomllib.loads(
        (root / "PROJECT_POLICY.toml").read_text(encoding="utf-8")
    )


def diff_check_command(
    base_ref: str,
    head_ref: str,
    locked_files: frozenset[str],
) -> list[str]:
    exclusions = [
        f":(top,exclude,literal){path}"
        for path in sorted(locked_files)
    ]

    return [
        "git",
        "diff",
        "--check",
        base_ref,
        head_ref,
        "--",
        ".",
        *exclusions,
    ]


def run_diff_check(
    root: Path,
    base_ref: str,
    head_ref: str,
    locked_files: frozenset[str],
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        diff_check_command(base_ref, head_ref, locked_files),
        cwd=root,
        check=False,
        capture_output=True,
        text=True,
    )


def check_format(
    root: Path,
    policy: dict,
    base_ref: str,
    head_ref: str,
) -> int:
    verification = verify_gmtl_lock(root, policy)

    if verification.errors:
        for error in verification.errors:
            print(
                "format: GMTL lock verification failed: "
                f"{error}",
                file=sys.stderr,
            )
        return 1

    result = run_diff_check(
        root,
        base_ref,
        head_ref,
        verification.files,
    )
    sys.stdout.write(result.stdout)
    sys.stderr.write(result.stderr)
    return result.returncode


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-ref", required=True)
    parser.add_argument("--head-ref", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    policy = load_policy(ROOT)
    return check_format(
        ROOT,
        policy,
        args.base_ref,
        args.head_ref,
    )


if __name__ == "__main__":
    raise SystemExit(main())
