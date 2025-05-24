#!/usr/bin/env python3

"""
Parse hashcat hashmodes file to JSON.

Usage:
    python scripts/dev/parse_hashcat_hashmodes.py --input-file hashcat_hashmodes.txt --output-file app/resources/hash_modes.json
"""

import argparse
import re
from pathlib import Path

from app.schemas.shared import HashModeItem, HashModeMetadata


def parse_hashcat_hashmodes(input_path: str) -> HashModeMetadata:
    path = Path(input_path)
    if not path.exists():
        raise FileNotFoundError(f"Input file not found: {input_path}")
    metadata = HashModeMetadata()
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            m = re.match(r"\s*(\d+) \| ([^|]+)\| ([^|]+)", line)
            if m:
                hash_mode = HashModeItem(
                    mode=int(m.group(1)),
                    name=m.group(2).strip(),
                    category=m.group(3).strip(),
                )
                metadata.hash_mode_map[hash_mode.mode] = hash_mode
                metadata.category_map[hash_mode.mode] = hash_mode.category
    return metadata


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Parse hashcat hashmodes file to JSON."
    )
    parser.add_argument("input_file", help="Path to hashcat hashmodes text file")
    parser.add_argument(
        "-o",
        "--output",
        default="app/resources/hash_modes.json",
        help="Output JSON file path",
    )
    args = parser.parse_args()
    data: HashModeMetadata = parse_hashcat_hashmodes(args.input_file)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(data.model_dump_json(indent=2), encoding="utf-8")
    print(f"Wrote {output_path}")


if __name__ == "__main__":
    main()
