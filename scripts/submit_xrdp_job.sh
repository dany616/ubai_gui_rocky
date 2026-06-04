#!/usr/bin/env bash
set -euo pipefail

env_file="${1:-config/session.env}"
if [ ! -f "$env_file" ]; then
  echo "[ERROR] env file not found: $env_file" >&2
  echo "Usage: $0 config/session.env" >&2
  exit 2
fi

abs_env_file="$(readlink -f "$env_file")"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

# shellcheck disable=SC1090
source "$abs_env_file"

sbatch_args=()
[ -n "${UBAI_SLURM_PARTITION:-}" ] && sbatch_args+=(--partition="$UBAI_SLURM_PARTITION")
[ -n "${UBAI_SLURM_TIME:-}" ] && sbatch_args+=(--time="$UBAI_SLURM_TIME")
[ -n "${UBAI_SLURM_CPUS_PER_TASK:-}" ] && sbatch_args+=(--cpus-per-task="$UBAI_SLURM_CPUS_PER_TASK")
[ -n "${UBAI_SLURM_MEM:-}" ] && sbatch_args+=(--mem="$UBAI_SLURM_MEM")
[ -n "${UBAI_SLURM_GPUS:-}" ] && sbatch_args+=(--gres="gpu:${UBAI_SLURM_GPUS}")
[ -n "${UBAI_SLURM_NODELIST:-}" ] && sbatch_args+=(--nodelist="$UBAI_SLURM_NODELIST")

mkdir -p "$repo_root/logs"

backend="${UBAI_CONTAINER_BACKEND:-enroot}"
case "$backend" in
  enroot)
    sbatch_file="$repo_root/slurm/ubai_cst_xrdp.sbatch"
    ;;
  podman)
    sbatch_file="$repo_root/slurm/ubai_cst_xrdp_podman.sbatch"
    ;;
  *)
    echo "[ERROR] Unsupported UBAI_CONTAINER_BACKEND: $backend" >&2
    echo "        Use enroot or podman." >&2
    exit 2
    ;;
esac

echo "[INFO] Submitting XRDP job with env: $abs_env_file"
echo "[INFO] Container backend: $backend"
sbatch "${sbatch_args[@]}" \
  --export=ALL,UBAI_ENV_FILE="$abs_env_file",UBAI_REPO_ROOT="$repo_root" \
  "$sbatch_file"
