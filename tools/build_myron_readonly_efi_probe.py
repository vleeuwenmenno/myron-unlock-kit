#!/usr/bin/env python3
"""Build a read-only loader probe from the exact reviewed SM8850 EFI payload."""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
from pathlib import Path

EXPECTED_SHA256 = "88918dd212fefe9d51c584513cbb7babebf395879d9edc2a02acd4246b5bcf5d"
PATCH_RVA = 0x1394
ORIGINAL = bytes.fromhex("20008052")  # mov w0, #1
REPLACEMENT = bytes.fromhex("16000014")  # b 0x13ec (print probe result, then return)
MESSAGE_RVA = 0x5CB0
ORIGINAL_MESSAGE = "VbRwStateApp: VBRwDeviceState(WRITE_CONFIG) success.\n"
PROBE_MESSAGE = "VbRwStateApp: READ-ONLY PROBE success; no write.\n"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def rva_to_offset(data: bytes, rva: int) -> int:
    if data[:2] != b"MZ":
        raise ValueError("input is not a PE image")
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe_offset : pe_offset + 4] != b"PE\0\0":
        raise ValueError("invalid PE signature")
    machine, section_count, _, _, _, optional_size = struct.unpack_from(
        "<HHIIIH", data, pe_offset + 4
    )
    if machine != 0xAA64:
        raise ValueError(f"expected AArch64 PE machine 0xaa64, got 0x{machine:04x}")
    section_table = pe_offset + 24 + optional_size
    for index in range(section_count):
        entry = section_table + index * 40
        virtual_size, virtual_address, raw_size, raw_offset = struct.unpack_from(
            "<IIII", data, entry + 8
        )
        if virtual_address <= rva < virtual_address + max(virtual_size, raw_size):
            return raw_offset + rva - virtual_address
    raise ValueError(f"RVA 0x{rva:x} is not mapped by a PE section")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()

    source = args.input.read_bytes()
    source_hash = sha256(source)
    if source_hash != EXPECTED_SHA256:
        raise SystemExit(
            f"refusing unreviewed input: expected {EXPECTED_SHA256}, got {source_hash}"
        )

    patch_offset = rva_to_offset(source, PATCH_RVA)
    found = source[patch_offset : patch_offset + len(ORIGINAL)]
    if found != ORIGINAL:
        raise SystemExit(
            f"unexpected instruction at RVA 0x{PATCH_RVA:x}: {found.hex()}"
        )

    probe = bytearray(source)
    probe[patch_offset : patch_offset + len(REPLACEMENT)] = REPLACEMENT
    message_offset = rva_to_offset(source, MESSAGE_RVA)
    original_message = (ORIGINAL_MESSAGE + "\0").encode("utf-16-le")
    probe_message = (PROBE_MESSAGE + "\0").encode("utf-16-le")
    if source[message_offset : message_offset + len(original_message)] != original_message:
        raise SystemExit("unexpected success message in reviewed input")
    if len(probe_message) > len(original_message):
        raise SystemExit("probe message does not fit in original string storage")
    probe[message_offset : message_offset + len(original_message)] = (
        probe_message + bytes(len(original_message) - len(probe_message))
    )
    changed = [i for i, (before, after) in enumerate(zip(source, probe)) if before != after]
    allowed = set(range(patch_offset, patch_offset + len(REPLACEMENT)))
    allowed.update(range(message_offset, message_offset + len(original_message)))
    if not changed or not set(changed).issubset(allowed):
        raise SystemExit(f"unexpected changed offsets: {changed}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(probe)
    manifest = {
        "purpose": "read-only EFI loader probe; READ_CONFIG, print success, return; no WRITE_CONFIG",
        "input_sha256": source_hash,
        "output_sha256": sha256(probe),
        "size": len(probe),
        "patch_rva": f"0x{PATCH_RVA:x}",
        "patch_file_offset": f"0x{patch_offset:x}",
        "original_bytes": ORIGINAL.hex(),
        "replacement_bytes": REPLACEMENT.hex(),
        "message_rva": f"0x{MESSAGE_RVA:x}",
        "message_file_offset": f"0x{message_offset:x}",
        "probe_message": PROBE_MESSAGE,
        "changed_byte_count": len(changed),
    }
    manifest_path = args.output.with_suffix(args.output.suffix + ".json")
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
