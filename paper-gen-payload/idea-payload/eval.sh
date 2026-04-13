#!/usr/bin/env bash
set -euo pipefail

# Idea loop criteria are all LLM-evaluated (IDEA-001~004).
# Keep script output empty to satisfy PG-SPEC-007/008.
echo '{"results":[]}'
