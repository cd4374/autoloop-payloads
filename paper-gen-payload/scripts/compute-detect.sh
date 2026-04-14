#!/usr/bin/env bash
# =============================================================================
# compute-detect.sh — Compute environment detection for paper-gen-payload
# =============================================================================
# Priority order: SSH remote GPU → Local CUDA GPU → Local MPS → CPU
#
# Usage:
#   scripts/compute-detect.sh [--dry-run] [--verbose]
#
# Environment variables (override config file):
#   COMPUTE_SSH_HOST     SSH host for remote GPU (e.g. user@gpu-server)
#   COMPUTE_SSH_KEY      Path to SSH private key
#   COMPUTE_SSH_ENABLED   "true" to enable SSH GPU (default: "true")
#   COMPUTE_CUDA_ENABLED  "true" to enable local CUDA check (default: "true")
#   COMPUTE_MPS_ENABLED   "true" to enable local MPS check (default: "true")
#   COMPUTE_CONDA_ENV     Conda environment name (default: scf-paper)
#   COMPUTE_TIMEOUT       Seconds for SSH/exec timeout (default: 10)
#
# Output:
#   Writes .paper/state/compute-env.json with detected environment info.
#
# Exit codes:
#   0  = detection successful (even if no GPU found, CPU is valid)
#   1  = detection failed (unexpected error)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_DIR="${PAYLOAD_ROOT}/.paper/state"
OUTPUT_DIR="${PAYLOAD_ROOT}/.paper/output"
COMPUTE_ENV_FILE="${COMPUTE_ENV_FILE:-${STATE_DIR}/compute-env.json}"
COMPUTE_CONFIG_FILE="${COMPUTE_CONFIG_FILE:-${STATE_DIR}/compute-config.json}"

DRY_RUN="${COMPUTE_DRY_RUN:-false}"
VERBOSE="${COMPUTE_VERBOSE:-false}"
TIMEOUT="${COMPUTE_TIMEOUT:-10}"
CONDA_ENV="${COMPUTE_CONDA_ENV:-scf-paper}"

# Config file keys (lowercased for consistency)
SSH_ENABLED="${COMPUTE_SSH_ENABLED:-true}"
CUDA_ENABLED="${COMPUTE_CUDA_ENABLED:-true}"
MPS_ENABLED="${COMPUTE_MPS_ENABLED:-true}"
SSH_HOST="${COMPUTE_SSH_HOST:-}"
SSH_KEY="${COMPUTE_SSH_KEY:-}"

log() { echo "[compute-detect] $*" >&2; }
logv() { [[ "$VERBOSE" == "true" ]] && log "$@"; }

# ---------------------------------------------------------------------------
# Helper: read a key from the JSON config file
# ---------------------------------------------------------------------------
read_config() {
    local key="$1"
    python3 - <<PYEOF 2>/dev/null
import json, sys
try:
    with open('$COMPUTE_CONFIG_FILE') as f:
        d = json.load(f)
    v = d.get('$key', '') or d.get('${key,,}', '')
    print(v)
except Exception:
    print('')
PYEOF
}

# ---------------------------------------------------------------------------
# Stage 0: Load user config (optional)
# ---------------------------------------------------------------------------
load_config() {
    if [[ -f "$COMPUTE_CONFIG_FILE" ]]; then
        logv "Loading config from $COMPUTE_CONFIG_FILE"
        local cfg_ssh_host cfg_ssh_key cfg_ssh_en cfg_cuda_en cfg_mps_en
        cfg_ssh_host=$(read_config "ssh_host")
        cfg_ssh_key=$(read_config "ssh_key")
        cfg_ssh_en=$(read_config "ssh_enabled")
        cfg_cuda_en=$(read_config "cuda_enabled")
        cfg_mps_en=$(read_config "mps_enabled")

        [[ -n "$cfg_ssh_host" ]] && SSH_HOST="$cfg_ssh_host"
        [[ -n "$cfg_ssh_key" ]]  && SSH_KEY="$cfg_ssh_key"
        [[ -n "$cfg_ssh_en" ]]   && SSH_ENABLED="$cfg_ssh_en"
        [[ -n "$cfg_cuda_en" ]]  && CUDA_ENABLED="$cfg_cuda_en"
        [[ -n "$cfg_mps_en" ]]   && MPS_ENABLED="$cfg_mps_en"
    fi
}

# ---------------------------------------------------------------------------
# Stage 1: SSH remote GPU detection
# ---------------------------------------------------------------------------
detect_ssh_gpu() {
    local host="$1"
    local key="$2"
    local result_file
    result_file=$(mktemp)

    logv "Checking SSH GPU at $host"

    local ssh_opts=("-o" "StrictHostKeyChecking=no" "-o" "BatchMode=yes" "-o" "ConnectTimeout=${TIMEOUT}")
    [[ -n "$key" ]] && ssh_opts+=("-i" "$key")

    # Run nvidia-smi on remote, capture GPU info and exit code
    local out rc
    out=$(ssh "${ssh_opts[@]}" "$host" "nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader" 2>/dev/null || echo "__SSH_FAIL__")
    rc=$?

    if [[ "$out" == "__SSH_FAIL__" ]] || [[ "$rc" -ne 0 ]]; then
        logv "SSH GPU check failed for $host"
        rm -f "$result_file"
        return 1
    fi

    local gpu_name gpu_mem driver_version
    IFS=',' read -r gpu_name gpu_mem driver_version <<< "$(echo "$out" | head -n1 | sed 's/^ *//;s/ *$//')"
    gpu_name="${gpu_name:-unknown}"
    gpu_mem="${gpu_mem:-N/A}"
    driver_version="${driver_version:-N/A}"

    log "SSH GPU detected: $gpu_name ($gpu_mem, driver $driver_version)"

    cat > "$result_file" <<EOF
{
  "device": "ssh_gpu",
  "hostname": "$(echo "$host" | sed 's/@.*$//')",
  "gpu_name": "$(echo "$gpu_name" | sed 's/"/\\"/g')",
  "gpu_memory": "$(echo "$gpu_mem" | sed 's/"/\\"/g')",
  "driver_version": "$(echo "$driver_version" | sed 's/"/\\"/g')",
  "ssh_host": "$(echo "$host" | sed 's/"/\\"/g')",
  "cuda_version": "via_remote_nvidia_smi",
  "available": true
}
EOF
    mv "$result_file" "$COMPUTE_ENV_FILE"
    return 0
}

# ---------------------------------------------------------------------------
# Stage 2: Local CUDA GPU detection
# ---------------------------------------------------------------------------
detect_local_cuda() {
    logv "Checking local CUDA GPU"

    # Check nvidia-smi first (most reliable, no Python dependency)
    local gpu_info rc
    gpu_info=$(nvidia-smi --query-gpu=name,memory.total,memory.free,driver_version,compute_cap --format=csv,noheader 2>/dev/null || echo "__CUDA_FAIL__")
    rc=$?

    if [[ "$gpu_info" != "__CUDA_FAIL__" ]] && [[ "$rc" -eq 0 ]]; then
        local gpu_name gpu_mem gpu_free driver_version compute_cap
        IFS=',' read -r gpu_name gpu_mem gpu_free driver_version compute_cap <<< "$(echo "$gpu_info" | head -n1 | sed 's/^ *//;s/ *$//')"
        gpu_name="${gpu_name:-unknown}"
        gpu_mem="${gpu_mem:-N/A}"
        gpu_free="${gpu_free:-N/A}"
        driver_version="${driver_version:-N/A}"
        compute_cap="${compute_cap:-N/A}"

        # Also try to get CUDA version from nvcc
        local cuda_ver="unknown"
        local nvcc_out
        nvcc_out=$(nvcc --version 2>/dev/null || echo "")
        if [[ -n "$nvcc_out" ]]; then
            cuda_ver=$(echo "$nvcc_out" | grep -oP 'release \K[0-9]+\.[0-9]+' | head -1 || echo "unknown")
        fi

        log "Local CUDA GPU detected: $gpu_name ($gpu_mem, driver $driver_version, CUDA $cuda_ver)"

        python3 - <<PYEOF
import json
with open('$COMPUTE_ENV_FILE', 'w') as f:
    json.dump({
        "device": "cuda",
        "gpu_name": "${gpu_name//\"/\\\"}",
        "gpu_memory_total": "${gpu_mem//\"/\\\"}",
        "gpu_memory_free": "${gpu_free//\"/\\\"}",
        "driver_version": "${driver_version//\"/\\\"}",
        "cuda_version": "${cuda_ver//\"/\\\"}",
        "compute_capability": "${compute_cap//\"/\\\"}",
        "available": True
    }, f, indent=2)
PYEOF
        return 0
    fi

    # Fallback: try torch.cuda (works even without nvidia-smi in PATH)
    local torch_out
    torch_out=$(python3 - <<'PYEOF' 2>/dev/null || echo "__TORCH_FAIL__"
import json, torch
try:
    if torch.cuda.is_available():
        dev = torch.cuda.get_device_name(0)
        mem_total = torch.cuda.get_device_properties(0).total_memory
        cuda_ver = torch.version.cuda or "unknown"
        print(json.dumps({
            "device": "cuda",
            "gpu_name": dev,
            "gpu_memory_total": str(mem_total),
            "cuda_version": cuda_ver,
            "available": True
        }))
    else:
        print("__TORCH_UNAVAIL__")
except Exception:
    print("__TORCH_FAIL__")
PYEOF
)
    if [[ "$torch_out" != "__TORCH_FAIL__" ]] && [[ "$torch_out" != "__TORCH_UNAVAIL__" ]] && [[ -n "$torch_out" ]]; then
        log "Local CUDA GPU detected via torch: $(echo "$torch_out" | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("gpu_name","?") + " CUDA " + d.get("cuda_version","?"))' 2>/dev/null || echo 'GPU')"
        echo "$torch_out" | python3 -c "
import json, sys
d = json.load(sys.stdin)
d['driver_version'] = ''
d['gpu_memory_free'] = ''
d['compute_capability'] = ''
with open('$COMPUTE_ENV_FILE', 'w') as f:
    json.dump(d, f, indent=2)
"
        return 0
    fi

    logv "No local CUDA GPU found"
    return 1
}

# ---------------------------------------------------------------------------
# Stage 3: Local MPS detection (Apple Silicon)
# ---------------------------------------------------------------------------
detect_local_mps() {
    logv "Checking local MPS (Apple Silicon)"

    local mps_available="false"
    local mps_mem="N/A"
    local device_name="Apple Silicon MPS"

    # Check sysctl for Apple Silicon
    local chip
    chip=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "")

    # Check if running on ARM (Apple Silicon)
    if [[ "$(uname -m)" == "arm64" ]] || [[ "$chip" == *"Apple"* ]]; then
        # Try PyTorch MPS
        local torch_out
        torch_out=$(python3 - <<'PYEOF' 2>/dev/null || echo "__TORCH_FAIL__"
import json, torch
try:
    if torch.backends.mps.is_available():
        print("__MPS_AVAILABLE__")
    else:
        print("__MPS_UNAVAIL__")
except Exception:
    print("__TORCH_FAIL__")
PYEOF
)
        if [[ "$torch_out" == "__MPS_AVAILABLE__" ]]; then
            mps_available="true"
            device_name="Apple Silicon MPS ($(sysctl -n hw.memsize 2>/dev/null | awk '{printf "%.1f GB", $1/1024/1024/1024}'))"
            log "Local MPS detected: $device_name"
        else
            logv "MPS not available via torch (torch_out=$torch_out)"
        fi
    else
        logv "Not ARM64 architecture, MPS not applicable"
        mps_available="false"
    fi

    # Only write result if MPS is actually available
    if [[ "$mps_available" == "true" ]]; then
        python3 - <<PYEOF
import json
with open('$COMPUTE_ENV_FILE', 'w') as f:
    json.dump({
        "device": "mps",
        "device_name": "${device_name//\"/\\\"}",
        "architecture": "$(uname -m)",
        "mps_available": True,
        "available": True
    }, f, indent=2)
PYEOF
        return 0
    else
        logv "MPS not available, falling through to CPU"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Stage 4: CPU fallback
# ---------------------------------------------------------------------------
detect_cpu() {
    log "Falling back to CPU"

    local cpu_name num_cores mem_total
    cpu_name=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -p)
    num_cores=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo "unknown")
    mem_total=$(sysctl -n hw.memsize 2>/dev/null || echo "0")
    mem_total_gb=$(echo "$mem_total" | awk '{printf "%.1f GB", $1/1024/1024/1024}')

    python3 - <<PYEOF
import json, platform, subprocess
try:
    hostname = platform.node()
except Exception:
    hostname = ''

try:
    cpu_freq = subprocess.check_output(['sysctl', '-n', 'hw.cpufrequency'], text=True).strip().split()[0]
    cpu_freq_ghz = str(round(int(cpu_freq) / 1e9, 2)) + ' GHz'
except Exception:
    cpu_freq_ghz = 'unknown'

num_cores_val = "$num_cores"
num_cores_int = int(num_cores_val) if num_cores_val.isdigit() else 0

with open('$COMPUTE_ENV_FILE', 'w') as f:
    json.dump({
        "device": "cpu",
        "device_name": "${cpu_name//\"/\\\"}",
        "num_cores": num_cores_int,
        "memory_total": "${mem_total_gb//\"/\\\"}",
        "cpu_frequency": cpu_freq_ghz,
        "available": True
    }, f, indent=2)
PYEOF
}

# ---------------------------------------------------------------------------
# Stage 5: Verify conda environment
# ---------------------------------------------------------------------------
check_conda_env() {
    local env_name="$1"
    logv "Checking conda environment: $env_name"

    if command -v conda &>/dev/null; then
        if conda env list 2>/dev/null | grep -q "^${env_name} " || true; then
            log "Conda environment '$env_name' found"
            return 0
        else
            log "Conda environment '$env_name' not found, will attempt to create"
            return 1
        fi
    else
        log "Conda not found in PATH"
        return 2
    fi
}

# ---------------------------------------------------------------------------
# Create conda environment if missing
# ---------------------------------------------------------------------------
ensure_conda_env() {
    local env_name="$1"

    if ! command -v conda &>/dev/null; then
        log "conda not available, skipping environment creation"
        return 0
    fi

    if conda env list 2>/dev/null | grep -q "^${env_name} " || true; then
        return 0
    fi

    log "Creating conda environment: $env_name"
    local create_out
    create_out=$(conda create -n "$env_name" -y python=3.11 2>&1 | tail -5) && true
    logv "$create_out"
    if conda env list 2>/dev/null | grep -q "^${env_name} " || true; then
        log "Conda environment '$env_name' created successfully"
    else
        log "WARNING: Conda environment '$env_name' may not have been created"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# Main detection logic
# ---------------------------------------------------------------------------
main() {
    mkdir -p "$STATE_DIR"

    log "Starting compute environment detection"
    log "Priority: SSH GPU → Local CUDA → Local MPS → CPU"

    # Load optional user config
    load_config

    # Detect in priority order — disable errexit here since [[ -n "" ]] returns 1
    # which should not cause script exit in the detection logic
    set +e
    local detected="false"

    # 1. SSH remote GPU
    if [[ "$SSH_ENABLED" == "true" ]] && [[ -n "$SSH_HOST" ]]; then
        detect_ssh_gpu "$SSH_HOST" "$SSH_KEY" && detected="true"
    elif [[ "$SSH_ENABLED" == "true" ]]; then
        logv "SSH GPU enabled but COMPUTE_SSH_HOST not set, skipping"
    fi

    # 2. Local CUDA GPU
    if [[ "$detected" == "false" ]] && [[ "$CUDA_ENABLED" == "true" ]]; then
        detect_local_cuda && detected="true"
    fi

    # 3. Local MPS (Apple Silicon)
    if [[ "$detected" == "false" ]] && [[ "$MPS_ENABLED" == "true" ]]; then
        detect_local_mps && detected="true"
    fi

    # 4. CPU fallback
    if [[ "$detected" == "false" ]]; then
        detect_cpu
    fi
    set -e

    # Add metadata
    local ts conda_exists
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    conda_exists=$(command -v conda &>/dev/null && conda env list 2>/dev/null | grep -q "^${CONDA_ENV} " && echo "true" || echo "false" || echo "false")
    python3 - <<PYEOF
import json, sys, os
try:
    with open('$COMPUTE_ENV_FILE') as f:
        d = json.load(f)
    d['conda_env'] = '${CONDA_ENV}'
    d['conda_env_exists'] = True if "$conda_exists" == "true" else False
    d['detected_at'] = '${ts}'
    d['config_source'] = 'auto-detect'
    with open('$COMPUTE_ENV_FILE', 'w') as f:
        json.dump(d, f, indent=2)
except Exception as e:
    print(f"Warning: failed to annotate compute-env.json: {e}", file=sys.stderr)
PYEOF

    log "Detection complete. Output: $COMPUTE_ENV_FILE"

    # Ensure conda environment exists
    ensure_conda_env "$CONDA_ENV"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: not writing to $COMPUTE_ENV_FILE"
        cat "$COMPUTE_ENV_FILE"
        return 0
    fi

    # Show summary
    local device
    device=$(python3 -c "import json; d=json.load(open('$COMPUTE_ENV_FILE')); print(d.get('device','?'))" 2>/dev/null || echo "?")
    log "Selected compute device: $device"

    return 0
}

# Allow sourcing this file to access functions without running detection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
