#!/usr/bin/env python3
"""Check Home Stuff Inventory app-code coverage from an Xcode result bundle."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Optional


APP_SOURCE_PREFIXES = (
    "HomeStuffInventoryApp/InventoryData/",
    "HomeStuffInventoryApp/InventoryLogic/",
    "HomeStuffInventoryApp/InventoryPresentation/",
    "HomeStuffInventoryApp/Persistence/",
)

EXCLUDED_PATH_PARTS = (
    "/HomeStuffInventoryAppTests/",
    "/HomeStuffInventoryAppUITests/",
    "/HomeStuffInventoryApp/Views/",
    "/HomeStuffInventoryApp/Views/PreviewSupport/",
    "/DerivedData/",
    "/Build/",
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fail when selected app-code line coverage is below a threshold."
    )
    parser.add_argument("result_bundle", help="Path to the coverage .xcresult bundle.")
    parser.add_argument(
        "--minimum",
        type=float,
        default=80.0,
        help="Minimum required coverage percentage. Defaults to 80.0.",
    )
    parser.add_argument(
        "--target",
        default="HomeStuffInventoryApp.app",
        help="xccov target name to inspect. Defaults to HomeStuffInventoryApp.app.",
    )
    args = parser.parse_args()

    result_bundle = Path(args.result_bundle)
    if not result_bundle.exists():
        print(f"Coverage result bundle not found: {result_bundle}", file=sys.stderr)
        return 2

    report = load_xccov_report(result_bundle)
    target = find_target(report, args.target)
    if target is None:
        available = ", ".join(sorted(t.get("name", "<unknown>") for t in report.get("targets", [])))
        print(f"Coverage target '{args.target}' not found. Available targets: {available}", file=sys.stderr)
        return 2

    files = selected_files(target.get("files", []))
    if not files:
        print("No covered app-code files matched the configured coverage scope.", file=sys.stderr)
        return 2

    covered_lines = sum(int(file.get("coveredLines", 0)) for file in files)
    executable_lines = sum(int(file.get("executableLines", 0)) for file in files)
    if executable_lines == 0:
        print("Matched app-code files have no executable lines.", file=sys.stderr)
        return 2

    coverage = covered_lines / executable_lines * 100

    print("Coverage scope:")
    print("  Included: InventoryData, InventoryLogic, InventoryPresentation, Persistence")
    print("  Excluded: tests, generated/build artifacts, SwiftUI Views, preview support")
    print("")
    print(f"Covered lines: {covered_lines}/{executable_lines}")
    print(f"Coverage: {coverage:.2f}%")
    print(f"Minimum: {args.minimum:.2f}%")
    print("")
    print("Lowest-covered included files:")
    for file in sorted(files, key=lambda item: item_coverage(item))[:10]:
        line_coverage = item_coverage(file) * 100
        covered = int(file.get("coveredLines", 0))
        executable = int(file.get("executableLines", 0))
        print(f"  {line_coverage:6.2f}%  {covered:4d}/{executable:<4d}  {relative_name(file)}")

    if coverage + 1e-9 < args.minimum:
        print("")
        print(f"Coverage gate failed: {coverage:.2f}% is below {args.minimum:.2f}%.", file=sys.stderr)
        return 1

    print("")
    print(f"Coverage gate passed: {coverage:.2f}% meets {args.minimum:.2f}%.")
    return 0


def load_xccov_report(result_bundle: Path) -> dict:
    command = ["xcrun", "xccov", "view", "--report", "--json", str(result_bundle)]
    completed = subprocess.run(command, check=True, capture_output=True, text=True)
    return json.loads(completed.stdout)


def find_target(report: dict, preferred_name: str) -> Optional[dict]:
    targets = report.get("targets", [])
    for target in targets:
        if target.get("name") == preferred_name:
            return target

    for target in targets:
        name = target.get("name", "")
        if name.startswith("HomeStuffInventoryApp") and "Tests" not in name:
            return target

    return None


def selected_files(files: list[dict]) -> list[dict]:
    selected = []
    for file in files:
        normalized = normalized_name(file)
        if any(part in normalized for part in EXCLUDED_PATH_PARTS):
            continue
        if any(relative_name(file).startswith(prefix) for prefix in APP_SOURCE_PREFIXES):
            selected.append(file)
    return selected


def relative_name(file: dict) -> str:
    normalized = normalized_name(file)
    marker = "/HomeStuffInventoryApp/"
    if marker in normalized:
        return "HomeStuffInventoryApp/" + normalized.split(marker, 1)[1]
    if normalized.startswith("HomeStuffInventoryApp/"):
        return normalized
    return normalized


def item_coverage(file: dict) -> float:
    executable = int(file.get("executableLines", 0))
    if executable == 0:
        return 1.0
    return int(file.get("coveredLines", 0)) / executable


def normalized_name(file: dict) -> str:
    name = str(file.get("path") or file.get("name") or "")
    return name.replace("\\", "/")


if __name__ == "__main__":
    sys.exit(main())
