#!/usr/bin/env python3
import argparse
import json
from datetime import datetime, timezone
from pathlib import Path

import yaml


def load_metadata(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    return data


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Sample research entrypoint that consumes dataset metadata."
    )
    parser.add_argument("--exp", default="exp001", help="Experiment identifier")
    parser.add_argument(
        "--metadata",
        default=str(Path(__file__).resolve().parent.parent / "data" / "metadata.yaml"),
        help="Path to dataset metadata",
    )
    parser.add_argument(
        "--run-dir",
        default=str(Path(__file__).resolve().parent.parent / "runs" / "exp001"),
        help="Directory to store run outputs",
    )
    args = parser.parse_args()

    run_dir = Path(args.run_dir)
    run_dir.mkdir(parents=True, exist_ok=True)

    metadata = load_metadata(Path(args.metadata))

    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "experiment": args.exp,
        "dataset": metadata.get("dataset_name"),
        "dataset_version": metadata.get("version"),
        "source": metadata.get("source_url"),
        "columns": metadata.get("columns", []),
        "notes": "replace this stub with your experiment logic",
    }

    out_file = run_dir / "results.jsonl"
    with out_file.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record) + "\n")

    print(f"record appended to {out_file}")


if __name__ == "__main__":
    main()
