"""파일을 원본 폴더의 SB 바이너리 컨테이너로 저장한다."""

import os
from pathlib import Path
import stat
import struct
import sys


# Little endian: magic(4), version(2), UTF-8 filename length(2), payload size(8).
HEADER = struct.Struct("<4sHHQ")
CHUNK_SIZE = 1024 * 1024


def create_output(source: Path):
    """기존 파일을 덮어쓰지 않도록 생성 자체를 배타적으로 수행한다."""
    index = 0
    while True:
        suffix = "" if index == 0 else f" ({index})"
        output = source.with_name(f"{source.name}{suffix}.sb")
        try:
            return output, output.open("xb")
        except FileExistsError:
            index += 1


def copy_payload(source, destination, expected_size: int):
    remaining = expected_size
    while remaining:
        chunk = source.read(min(CHUNK_SIZE, remaining))
        if not chunk:
            raise OSError("처리 중 원본 파일 크기가 변경됐습니다.")
        destination.write(chunk)
        remaining -= len(chunk)
    if source.read(1):
        raise OSError("처리 중 원본 파일 크기가 변경됐습니다.")


def pack_file(path: str | Path) -> Path:
    source = Path(path).absolute()
    if not source.is_file():
        raise ValueError("일반 파일만 처리할 수 있습니다. 경로를 확인해주세요.")
    filename = source.name.encode("utf-8")
    if len(filename) > 65535:
        raise ValueError("파일명이 SB 형식의 길이 제한을 초과했습니다.")

    with source.open("rb") as original:
        before = os.fstat(original.fileno())
        if not stat.S_ISREG(before.st_mode):
            raise ValueError("일반 파일만 처리할 수 있습니다.")
        header = HEADER.pack(b"SBIN", 1, len(filename), before.st_size)
        output, stream = create_output(source)
        try:
            with stream:
                stream.write(header)
                stream.write(filename)
                # 큰 파일도 통째로 메모리에 올리지 않고 순서대로 기록한다.
                copy_payload(original, stream, before.st_size)
                after = os.fstat(original.fileno())
                if (before.st_size, before.st_mtime_ns) != (
                    after.st_size, after.st_mtime_ns
                ):
                    raise OSError("처리 중 원본 파일이 변경됐습니다. 다시 시도해주세요.")
        except BaseException:
            # 이번 실행에서 만든 불완전한 결과만 제거한다.
            output.unlink(missing_ok=True)
            raise
    return output


def main(arguments: list[str]) -> int:
    if not arguments:
        print("Binary Packer - 파일을 .sb 형식으로 저장합니다.")
        print("파일을 하나 또는 여러 개 선택해 BinaryPacker.exe 아이콘 위에 놓으세요.")
        print("결과는 원본과 같은 폴더에 저장됩니다. 원본은 유지됩니다.")
        print("사용법: BinaryPacker.exe 파일경로 [파일경로 ...]")
        return 0

    failures = 0
    for path in arguments:
        try:
            output = pack_file(path)
            print(f"[완료] {output}")
        except (OSError, ValueError) as error:
            failures += 1
            print(f"[실패] {path}: {error}", file=sys.stderr)
    print(f"완료 {len(arguments) - failures}개 / 실패 {failures}개")
    return 1 if failures else 0


if __name__ == "__main__":
    # Windows 콘솔에서 표시할 수 없는 문자가 결과 저장을 방해하지 않게 한다.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="replace")
    try:
        exit_code = main(sys.argv[1:])
    except KeyboardInterrupt:
        print("\n작업을 취소했습니다.", file=sys.stderr)
        exit_code = 130
    # 탐색기에서 실행했을 때 결과를 읽을 수 있게 창을 유지한다.
    if getattr(sys, "frozen", False) and sys.stdin and sys.stdin.isatty():
        try:
            input("Enter 키를 누르면 종료합니다.")
        except (EOFError, KeyboardInterrupt):
            pass
    raise SystemExit(exit_code)
