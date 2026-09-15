# Binary Packer v1.1.0

C++17과 Windows API로 작성한 파일 포장 도구다. `BinaryPacker.exe`에 파일을 드롭하면 원본 폴더에 `.sb` 파일을 만든다. SB는 Seok Binary의 약자다.

[실행 파일 다운로드](https://github.com/Cocode96/Dev-Exploration-Lab/releases/tag/binary-packer-v1.1.0)

## 실행

릴리즈의 `BinaryPacker-v1.1.0-win64.zip`을 내려받아 압축을 풀고 `BinaryPacker.exe`를 실행한다. 파일 하나 또는 여러 개를 EXE 아이콘에 드롭할 수 있다. Python이나 Visual Studio 설치 없이 Windows x64에서 실행한다. C++ 런타임은 정적으로 링크한다.

```text
입력: C:\Assets\image.png
결과: C:\Assets\image.png.sb
다시 입력: C:\Assets\image.png (1).sb
```

탐색기에서 열면 결과를 읽은 뒤 Enter로 닫는다. 터미널에서는 처리 후 종료하며, 실패한 파일이 있으면 종료 코드 1을 반환한다. 인자 없이 실행하면 사용 안내를 표시한다.

```powershell
& .\BinaryPacker.exe 'C:\Assets\image.png' 'C:\Assets\설정 파일.json'
```

원본과 기존 결과는 덮어쓰지 않는다. 폴더와 없는 경로는 실패로 처리하고 다음 입력을 계속 처리한다. 파일을 1 MiB씩 읽으며, 기록에 실패하면 이번에 만든 불완전한 결과만 삭제한다. 삭제에도 실패하면 해당 경로를 표시한다.

처리 중 원본 쓰기와 삭제를 막도록 파일 공유 모드를 설정한다. 다른 프로그램이 이미 쓰기 권한으로 열었다면 실패한다. 처리 전후의 파일 크기와 수정 시각도 확인한다.

이 도구는 파일명, 크기와 원본 바이트를 하나의 컨테이너에 저장한다. 복원, 압축, 암호화나 엔진 전용 리소스 변환 기능은 없다.

## Visual Studio에서 빌드

Visual Studio의 C++ 데스크톱 개발 도구, MSVC v143과 Windows SDK가 필요하다. `BinaryPacker.sln`을 열고 `Release | x64`로 빌드한다.

- `BinaryPacker.cpp`: 진입점, 파일 처리와 SB 기록
- `BinaryPacker.rc`: 실행 파일의 릴리즈 버전
- `BinaryPacker.vcxproj`: C++17, 경고 수준 4, 경고를 오류로 처리, 정적 런타임 설정

빌드, 실행 검증과 패키징을 한 번에 수행하려면 다음을 실행한다.

```powershell
.\build.ps1
```

| 산출물 | 위치 |
|---|---|
| Release 빌드 | `build/x64/Release/BinaryPacker.exe` |
| 배포 실행 파일 | `dist/BinaryPacker.exe` |
| 버전별 패키지 | `dist/BinaryPacker-v1.1.0-win64.zip` |
| 패키지 SHA-256 | `dist/SHA256SUMS.txt` |

소스와 릴리즈는 `Dev-Exploration-Lab`에서 함께 관리한다. 빌드 산출물은 Git에 포함하지 않고 이 저장소의 GitHub Releases에 배포한다. 도구 릴리즈 태그는 `binary-packer-v1.1.0`이며, 실험실 전체 통합 패키지의 버전과는 별개다.

## 검증

2026-09-15 Windows x64에서 Release 빌드와 실행 파일 통합 검사 10개를 통과했다. 사용 안내, 한글/공백/이모지 경로, 빈 파일, 1 MiB를 넘는 바이너리, 기존 파일 보존과 충돌 번호, `.sb` 입력, 잘못된 입력 이후 일괄 처리, 쓰기 중인 원본 거부, SB v1 기준 바이트, EXE 버전을 확인했다. 각 정상 출력의 헤더, UTF-8 파일명과 전체 본문을 원본과 대조했다.

```powershell
.\tests\Verify.ps1 -Executable .\dist\BinaryPacker.exe
```

탐색기에서 실제 마우스로 드롭하는 동작, 디스크 공간 부족 중 정리와 다른 PC 실행은 검증하지 않았다.

## SB 형식 v1

기존 SB v1과 동일한 바이트 형식이다. 정수는 little endian이며 파일명에는 폴더 경로를 넣지 않는다. 출력은 원본보다 16바이트와 UTF-8 파일명 길이만큼 커진다.

| 위치 | 크기 | 내용 |
|---|---|---|
| 0 | 4바이트 | `SBIN` |
| 4 | 2바이트 | 형식 버전 `1` |
| 6 | 2바이트 | UTF-8 파일명 길이 N |
| 8 | 8바이트 | 원본 크기 M |
| 16 | N바이트 | UTF-8 원본 파일명 |
| 16 + N | M바이트 | 원본 바이트 |
