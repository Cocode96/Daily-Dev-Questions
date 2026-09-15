# Dev Exploration Lab

[![GitHub Discussions](https://img.shields.io/github/discussions/Cocode96/Dev-Exploration-Lab?logo=github&label=Discussions)](https://github.com/Cocode96/Dev-Exploration-Lab/discussions)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-3fb950.svg)](CONTRIBUTING.md)
[![Main Branch](https://img.shields.io/badge/main-protected-8957e5.svg?logo=github)](https://github.com/Cocode96/Dev-Exploration-Lab/branches)
[![Languages](https://img.shields.io/badge/language-Korean%20%7C%20English-58a6ff.svg)](#english)

> 게임 개발과 AX 기술에 관한 질문을 재현 가능한 실험으로 검증하고, 그 결과를 실제 프로젝트에 다시 적용합니다.<br>
> Reproducible experiments in game development and AX, carried back into real projects.

[실험](#실험) | [연구 흐름](#연구-흐름) | [질문하기](https://github.com/Cocode96/Dev-Exploration-Lab/discussions/categories/q-a) | [검증된 질문](questions/README.md) | [기여 가이드](CONTRIBUTING.md) | [English](#english)

## 이 저장소가 다루는 것

게임 클라이언트 프로그래머의 관점에서 다음 주제를 직접 구현하고 측정합니다.

- C++, DirectX, 렌더링 구조와 그래픽스 최적화
- Unity와 게임 클라이언트 구조
- Python 기반 측정 도구와 개발 자동화
- AI Agent와 게임 개발 AX 파이프라인
- 객체 모델, 메모리, 운영체제 등 구현에 연결되는 CS 주제

단순히 개념을 정리하는 데서 끝내지 않습니다. 궁금한 점을 작은 실험으로 분리하고, 동일한 조건에서 결과를 비교한 뒤, 유효한 결론을 원래 게임 프로젝트와 개발 도구에 다시 적용하는 것이 목표입니다.

## 연구 흐름

```text
Question → Hypothesis → Reproducible Experiment → Measurement → Conclusion → Project Application
```

1. [Discussions](https://github.com/Cocode96/Dev-Exploration-Lab/discussions/categories/q-a)에서 질문과 현재 가설을 공개합니다.
2. 비교 조건, 측정 지표, 예상 결과를 정하고 최소 실험을 설계합니다.
3. `experiments/`에 실행 가능한 코드, 환경, 원시 결과를 남깁니다.
4. 수치와 시각적 결과를 바탕으로 결론과 한계를 기록합니다.
5. 실제 프로젝트에 적용했다면 적용 전후의 변화와 판단 근거를 연결합니다.

실패한 가설도 보존합니다. 결과를 재현할 수 있고 다음 판단에 도움이 된다면 의미 있는 기록으로 취급합니다.

## 도구

- [Binary Packer](https://github.com/Cocode96/BinaryPacker), 파일을 EXE에 드롭해 같은 폴더에 `.sb` 바이너리 컨테이너로 저장하는 독립 C++ 도구. [실행 파일 다운로드](https://github.com/Cocode96/BinaryPacker/releases/latest)

재사용하는 개발 도구는 `tools/`에 모은다. 기존 Python benchmark runner는 현재 `experiments/python/benchmark-runner/`에 있으며, 기존 실험과 문서의 폴더는 아직 이동하지 않았다.

## 실험

### Game development and graphics

- [런타임 렌더러 DLL 교체 구조](questions/game-development/q004-runtime-renderer-dll-swap/README.md)
- [작은 Update의 CPU, 멀티스레드, Compute Shader 손익분기점](questions/game-development/q005-update-parallel-break-even/README.md)

### Experiment tooling

- [Python benchmark runner](experiments/python/benchmark-runner/README.md), 반복 실행, 워밍업, CSV 기록을 위한 경량 측정 도구
- [Q004 raw benchmark results](experiments/python/benchmark-runner/reports/q004-dll-architecture-comparison/raw_results.csv)
- [DX11 Update break-even experiment](experiments/cpp/dx11-update-break-even/README.md), CPU 단일 스레드, 작업 스레드, Compute Shader 비교

다음 그래픽스 비교 실험은 같은 장면, 같은 하드웨어, 같은 측정 조건을 우선합니다. 예를 들어 WBOIT와 Z-Sorting은 성능뿐 아니라 교차 반투명 오브젝트, 깊이 복잡도, 시각적 오류를 함께 비교합니다.

## 저장소 구조

```text
tools/         여러 프로젝트에서 재사용하는 개발 도구
experiments/   실행 가능한 실험 코드, 설정, 원시 측정 결과
questions/     토론을 거쳐 검증한 질문과 결론
```

실험이 실제 프로젝트에 적용되면 해당 프로젝트의 커밋이나 문서로 연결해 실험과 제품 코드의 역할을 분리합니다.

## 공개 협업

- 질문과 초기 가설은 Discussion에서 자유롭게 나눕니다.
- 반례, 공식 문서, 프로파일링 결과와 재현 가능한 코드를 환영합니다.
- 검증된 문서와 실험은 작업 브랜치 또는 fork에서 PR로 제안합니다.
- `main` 직접 push와 force push는 허용하지 않습니다.
- 자세한 기준은 [CONTRIBUTING.md](CONTRIBUTING.md)를 따릅니다.

## English

Dev Exploration Lab is a public engineering notebook for reproducible experiments in game development, computer graphics, C++, Python, and AI-assisted development workflows.

The repository follows a practical loop: start with a question, state a hypothesis, build a controlled experiment, measure the result, document the limits, and apply useful findings back to a real project. Discussions hold open questions and early reasoning. The repository preserves executable experiments, raw results, and verified conclusions.

Current work includes runtime renderer DLL architecture experiments and a Python benchmark runner. Planned graphics studies, such as WBOIT versus Z-Sorting, will compare performance and visual correctness under controlled conditions.

Wrong hypotheses are welcome. Reproducibility, evidence, and practical application matter more than being correct on the first try.
