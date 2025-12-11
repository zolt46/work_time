#!/usr/bin/env bash
set -euo pipefail
# Render 실행 시 백엔드 패키지를 확실히 찾도록 작업 디렉터리를 저장소 루트로 이동하고
# PYTHONPATH에 루트를 추가합니다.
cd "$(dirname "$0")"
export PYTHONPATH="${PYTHONPATH:+$PYTHONPATH:}$(pwd)"
exec uvicorn backend.main:app --host 0.0.0.0 --port "${PORT:-8000}"
