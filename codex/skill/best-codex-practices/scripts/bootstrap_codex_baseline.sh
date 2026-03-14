#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bootstrap_codex_baseline.sh [--root <path>] [--force] [--probe] [--probe-json <path>] [--strict-simulate] [--strict-separator-bytes <n>] [--verify-with-codex] [--no-append-block]

Options:
  --root <path>  Base path to detect repository root (default: current directory)
  --force        Overwrite existing AGENTS.md and .codex/config.toml (with timestamp backups, high risk)
  --probe        Print instruction discovery chain before writing files
  --probe-json <path>
                 Write probe result as JSON report (implies --probe)
  --strict-simulate
                 Add stricter load simulation (blank-line separators + cap behavior), implies --probe
  --strict-separator-bytes <n>
                 Separator bytes between concatenated docs in strict simulation (default: 2)
  --verify-with-codex
                 Run live Codex probes and include outputs for cross-check (implies --probe)
  --no-append-block
                 When AGENTS.md exists and --force is not set, skip AGENTS.md update
  -h, --help     Show this help message

Behavior:
  - If inside a git repository, writes to the git top-level root.
  - If not in a git repository, writes to the provided/current directory.
  - Default mode updates/creates a managed block in AGENTS.md.
  - config.toml is created only when missing unless --force is used.
EOF
}

ROOT_INPUT="$(pwd)"
FORCE=0
PROBE=0
PROBE_JSON=""
STRICT_SIM=0
STRICT_SEPARATOR_BYTES=2
VERIFY_WITH_CODEX=0
APPEND_BLOCK=1

BASELINE_START='<!-- CODEX-BASELINE:START -->'
BASELINE_END='<!-- CODEX-BASELINE:END -->'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || { echo "[ERROR] --root requires a path"; exit 1; }
      ROOT_INPUT="$2"
      shift 2
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --probe)
      PROBE=1
      shift
      ;;
    --probe-json)
      [[ $# -ge 2 ]] || { echo "[ERROR] --probe-json requires a path"; exit 1; }
      PROBE_JSON="$2"
      PROBE=1
      shift 2
      ;;
    --strict-simulate)
      STRICT_SIM=1
      PROBE=1
      shift
      ;;
    --strict-separator-bytes)
      [[ $# -ge 2 ]] || { echo "[ERROR] --strict-separator-bytes requires a value"; exit 1; }
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "[ERROR] --strict-separator-bytes must be a non-negative integer"
        exit 1
      fi
      STRICT_SEPARATOR_BYTES="$2"
      STRICT_SIM=1
      PROBE=1
      shift 2
      ;;
    --verify-with-codex)
      VERIFY_WITH_CODEX=1
      PROBE=1
      shift
      ;;
    --no-append-block)
      APPEND_BLOCK=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[ERROR] Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$ROOT_INPUT" ]]; then
  echo "[ERROR] Path does not exist or is not a directory: $ROOT_INPUT"
  exit 1
fi

if GIT_ROOT="$(git -C "$ROOT_INPUT" rev-parse --show-toplevel 2>/dev/null)"; then
  TARGET_ROOT="$GIT_ROOT"
  ROOT_SOURCE="git root"
else
  TARGET_ROOT="$(cd "$ROOT_INPUT" && pwd)"
  ROOT_SOURCE="provided/current directory"
fi

ROOT_INPUT_ABS="$(cd "$ROOT_INPUT" && pwd)"
AGENTS_PATH="$TARGET_ROOT/AGENTS.md"
CODEX_DIR="$TARGET_ROOT/.codex"
CONFIG_PATH="$CODEX_DIR/config.toml"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

mkdir -p "$CODEX_DIR"

resolve_codex_home() {
  python3 - "$ROOT_INPUT_ABS" "${CODEX_HOME:-$HOME/.codex}" <<'PY'
import os
import pathlib
import sys

cwd = pathlib.Path(sys.argv[1])
raw = os.path.expanduser(sys.argv[2])
path = pathlib.Path(raw)
if not path.is_absolute():
    path = cwd / path
print(path.resolve())
PY
}

get_fallback_filenames() {
  local target_config="$TARGET_ROOT/.codex/config.toml"
  local codex_home
  codex_home="$(resolve_codex_home)"
  local home_config="$codex_home/config.toml"
  python3 - "$target_config" "$home_config" <<'PY'
import pathlib
import sys

def load_fallback(path: pathlib.Path):
    if not path.exists():
        return None
    try:
        import tomllib
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    value = data.get("project_doc_fallback_filenames")
    if isinstance(value, list):
        cleaned = [x for x in value if isinstance(x, str) and x.strip()]
        return cleaned if cleaned else None
    return None

target = pathlib.Path(sys.argv[1])
home = pathlib.Path(sys.argv[2])

fallback = load_fallback(target)
if fallback is None:
    fallback = load_fallback(home) or []

for item in fallback:
    print(item)
PY
}

get_project_doc_max_bytes() {
  local target_config="$TARGET_ROOT/.codex/config.toml"
  local codex_home
  codex_home="$(resolve_codex_home)"
  local home_config="$codex_home/config.toml"
  python3 - "$target_config" "$home_config" <<'PY'
import pathlib
import sys

DEFAULT_MAX = 32768

def load_max(path: pathlib.Path):
    if not path.exists():
        return None
    try:
        import tomllib
        data = tomllib.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None
    value = data.get("project_doc_max_bytes")
    if isinstance(value, int) and value > 0:
        return value
    return None

target = pathlib.Path(sys.argv[1])
home = pathlib.Path(sys.argv[2])

max_bytes = load_max(target)
if max_bytes is None:
    max_bytes = load_max(home)
if max_bytes is None:
    max_bytes = DEFAULT_MAX

print(max_bytes)
PY
}

probe_instruction_chain() {
  local fallbacks=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && fallbacks+=("$line")
  done < <(get_fallback_filenames)

  local order=("AGENTS.override.md" "AGENTS.md")
  if [[ ${#fallbacks[@]} -gt 0 ]]; then
    order+=("${fallbacks[@]}")
  fi

  local max_bytes="32768"
  max_bytes="$(get_project_doc_max_bytes)"
  local codex_home
  codex_home="$(resolve_codex_home)"
  local probe_json_path="$PROBE_JSON"
  local probe_entries_tmp=""
  local probe_strict_entries_tmp=""
  local probe_dirs_tmp=""
  local probe_order_tmp=""
  local strict_separator_bytes="$STRICT_SEPARATOR_BYTES"
  local strict_candidate_total_bytes=0
  local strict_estimated_loaded_bytes=0
  local strict_truncated=0
  local verify_status="disabled"
  local verify_reason=""
  local verify_root_exit=-1
  local verify_scan_exit=-1
  local verify_root_output_tmp="/dev/null"
  local verify_scan_output_tmp="/dev/null"
  local delim=$'\x1f'
  if [[ -n "$probe_json_path" ]]; then
    probe_entries_tmp="$(mktemp)"
    probe_strict_entries_tmp="$(mktemp)"
    probe_dirs_tmp="$(mktemp)"
    probe_order_tmp="$(mktemp)"
    local ord=""
    for ord in "${order[@]}"; do
      printf '%s\n' "$ord" >> "$probe_order_tmp"
    done
  fi

  echo "[PROBE] Target root: $TARGET_ROOT ($ROOT_SOURCE)"
  echo "[PROBE] Scan start path: $ROOT_INPUT_ABS"
  echo "[PROBE] CODEX_HOME: $codex_home"
  echo "[PROBE] Candidate order per directory: ${order[*]}"
  echo "[PROBE] project_doc_max_bytes: $max_bytes"

  local scan_dirs=()
  while IFS= read -r dir; do
    [[ -n "$dir" ]] && scan_dirs+=("$dir")
  done < <(python3 - "$TARGET_ROOT" "$ROOT_INPUT_ABS" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
scan = Path(sys.argv[2]).resolve()
if root in [scan, *scan.parents]:
    chain = []
    cur = scan
    while True:
        chain.append(cur)
        if cur == root:
            break
        cur = cur.parent
    for p in reversed(chain):
        print(str(p))
else:
    print(str(root))
    if scan != root:
        print(str(scan))
PY
)

  local matched_paths=()
  local matched_scopes=()
  local matched_names=()
  local estimate_statuses=()
  local strict_statuses=()
  local global_hit_label="(none)"

  # Global scope: prefer first non-empty file at codex home.
  local global_file=""
  if [[ -s "$codex_home/AGENTS.override.md" ]]; then
    global_file="$codex_home/AGENTS.override.md"
    global_hit_label="AGENTS.override.md"
    echo "[PROBE] GLOBAL -> AGENTS.override.md"
  elif [[ -s "$codex_home/AGENTS.md" ]]; then
    global_file="$codex_home/AGENTS.md"
    global_hit_label="AGENTS.md"
    echo "[PROBE] GLOBAL -> AGENTS.md"
  else
    if [[ -e "$codex_home/AGENTS.override.md" || -e "$codex_home/AGENTS.md" ]]; then
      global_hit_label="(only empty files, ignored)"
      echo "[PROBE] GLOBAL -> (only empty files, ignored)"
    else
      global_hit_label="(none)"
      echo "[PROBE] GLOBAL -> (none)"
    fi
  fi
  if [[ -n "$probe_dirs_tmp" ]]; then
    printf '%s%s%s\n' "__GLOBAL__" "$delim" "$global_hit_label" >> "$probe_dirs_tmp"
  fi
  if [[ -n "$global_file" ]]; then
    matched_paths+=("$global_file")
    matched_scopes+=("GLOBAL")
    matched_names+=("$(basename "$global_file")")
  fi

  local dir=""
  for dir in "${scan_dirs[@]}"; do
    local hit_name=""
    local hit_path=""
    local name=""
    for name in "${order[@]}"; do
      if [[ -s "$dir/$name" ]]; then
        hit_name="$name"
        hit_path="$dir/$name"
        break
      fi
    done
    local hit_label=""
    if [[ -n "$hit_name" ]]; then
      hit_label="$hit_name"
      echo "[PROBE] $dir -> $hit_name"
      matched_paths+=("$hit_path")
      matched_scopes+=("PROJECT")
      matched_names+=("$hit_name")
    else
      local has_empty=0
      for name in "${order[@]}"; do
        if [[ -e "$dir/$name" ]]; then
          has_empty=1
          break
        fi
      done
      if [[ "$has_empty" -eq 1 ]]; then
        hit_label="(only empty files, ignored)"
        echo "[PROBE] $dir -> (only empty files, ignored)"
      else
        hit_label="(none)"
        echo "[PROBE] $dir -> (none)"
      fi
    fi
    if [[ -n "$probe_dirs_tmp" ]]; then
      printf '%s%s%s\n' "$dir" "$delim" "$hit_label" >> "$probe_dirs_tmp"
    fi
  done

  if [[ ${#matched_paths[@]} -eq 0 ]]; then
    echo "[PROBE] No instruction files matched in scan chain."
  fi

  local total_candidate_bytes=0
  local estimated_loaded_bytes=0
  local i=0
  local path=""
  for path in "${matched_paths[@]}"; do
    local scope="${matched_scopes[$i]}"
    local hit_name="${matched_names[$i]}"
    local size=0
    local status="LOAD_FULL"
    size="$(wc -c < "$path" | tr -d '[:space:]')"
    total_candidate_bytes=$((total_candidate_bytes + size))

    if (( estimated_loaded_bytes >= max_bytes )); then
      status="SKIP_CAP"
      echo "[PROBE] [SKIP_CAP][$scope][$hit_name] $path (${size} bytes)"
      estimate_statuses+=("$status")
      if [[ -n "$probe_entries_tmp" ]]; then
        printf '%s%s%s%s%s%s%s%s%s\n' \
          "$scope" "$delim" "$hit_name" "$delim" "$path" "$delim" "$size" "$delim" "$status" >> "$probe_entries_tmp"
      fi
      i=$((i + 1))
      continue
    fi

    if (( estimated_loaded_bytes + size > max_bytes )); then
      status="LOAD_PARTIAL"
      echo "[PROBE] [LOAD_PARTIAL][$scope][$hit_name] $path (${size} bytes)"
      estimated_loaded_bytes="$max_bytes"
      estimate_statuses+=("$status")
      if [[ -n "$probe_entries_tmp" ]]; then
        printf '%s%s%s%s%s%s%s%s%s\n' \
          "$scope" "$delim" "$hit_name" "$delim" "$path" "$delim" "$size" "$delim" "$status" >> "$probe_entries_tmp"
      fi
      i=$((i + 1))
      continue
    fi

    echo "[PROBE] [LOAD_FULL][$scope][$hit_name] $path (${size} bytes)"
    estimated_loaded_bytes=$((estimated_loaded_bytes + size))
    estimate_statuses+=("$status")
    if [[ -n "$probe_entries_tmp" ]]; then
      printf '%s%s%s%s%s%s%s%s%s\n' \
        "$scope" "$delim" "$hit_name" "$delim" "$path" "$delim" "$size" "$delim" "$status" >> "$probe_entries_tmp"
    fi
    i=$((i + 1))
  done

  echo "[PROBE] candidate_total_bytes=$total_candidate_bytes"
  echo "[PROBE] estimated_loaded_bytes=$estimated_loaded_bytes"
  if (( total_candidate_bytes > max_bytes )); then
    echo "[PROBE] WARNING: instruction files may be truncated by project_doc_max_bytes."
  fi

  if [[ "$VERIFY_WITH_CODEX" -eq 1 ]]; then
    if ! command -v codex >/dev/null 2>&1; then
      verify_status="unavailable"
      verify_reason="codex command not found"
      echo "[PROBE][VERIFY] codex command not found; skip live verification."
    else
      verify_root_output_tmp="$(mktemp)"
      verify_scan_output_tmp="$(mktemp)"
      local verify_prompt="Show which instruction files are active."

      if codex --cd "$TARGET_ROOT" --ask-for-approval never "$verify_prompt" > "$verify_root_output_tmp" 2>&1; then
        verify_root_exit=0
      else
        verify_root_exit=$?
      fi

      if codex --cd "$ROOT_INPUT_ABS" --ask-for-approval never "$verify_prompt" > "$verify_scan_output_tmp" 2>&1; then
        verify_scan_exit=0
      else
        verify_scan_exit=$?
      fi

      if [[ "$verify_root_exit" -eq 0 && "$verify_scan_exit" -eq 0 ]]; then
        verify_status="ok"
        verify_reason="both probes succeeded"
      elif [[ "$verify_root_exit" -eq 0 || "$verify_scan_exit" -eq 0 ]]; then
        verify_status="partial"
        verify_reason="one probe failed"
      else
        verify_status="failed"
        verify_reason="both probes failed"
      fi
      echo "[PROBE][VERIFY] status=$verify_status root_exit=$verify_root_exit scan_exit=$verify_scan_exit"
    fi
  fi

  if [[ "$STRICT_SIM" -eq 1 ]]; then
    echo "[PROBE][STRICT] separator_bytes_between_docs=$strict_separator_bytes"
    local strict_loaded=0
    local strict_idx=0
    local strict_path=""
    for strict_path in "${matched_paths[@]}"; do
      local strict_scope="${matched_scopes[$strict_idx]}"
      local strict_name="${matched_names[$strict_idx]}"
      local strict_size=0
      local sep=0
      local strict_status="LOAD_FULL"

      strict_size="$(wc -c < "$strict_path" | tr -d '[:space:]')"
      if (( strict_idx > 0 )); then
        sep="$strict_separator_bytes"
      fi
      strict_candidate_total_bytes=$((strict_candidate_total_bytes + strict_size + sep))

      if (( strict_loaded >= max_bytes )); then
        strict_status="SKIP_CAP"
      elif (( strict_loaded + sep >= max_bytes )); then
        strict_status="SKIP_CAP"
      elif (( strict_loaded + sep + strict_size > max_bytes )); then
        strict_status="LOAD_PARTIAL"
        strict_loaded="$max_bytes"
      else
        strict_status="LOAD_FULL"
        strict_loaded=$((strict_loaded + sep + strict_size))
      fi

      strict_statuses+=("$strict_status")
      echo "[PROBE][STRICT] [$strict_status][$strict_scope][$strict_name] $strict_path (size=${strict_size}, sep=${sep})"
      if [[ -n "$probe_strict_entries_tmp" ]]; then
        printf '%s%s%s%s%s%s%s%s%s%s%s\n' \
          "$strict_scope" "$delim" "$strict_name" "$delim" "$strict_path" "$delim" \
          "$strict_size" "$delim" "$sep" "$delim" "$strict_status" >> "$probe_strict_entries_tmp"
      fi
      strict_idx=$((strict_idx + 1))
    done

    strict_estimated_loaded_bytes="$strict_loaded"
    if (( strict_candidate_total_bytes > max_bytes )); then
      strict_truncated=1
    fi
    echo "[PROBE][STRICT] candidate_total_bytes_with_separators=$strict_candidate_total_bytes"
    echo "[PROBE][STRICT] estimated_loaded_bytes=$strict_estimated_loaded_bytes"
    if (( strict_truncated == 1 )); then
      echo "[PROBE][STRICT] WARNING: instruction files may be truncated by project_doc_max_bytes."
    fi

    local diff_count=0
    local diff_i=0
    while (( diff_i < ${#matched_paths[@]} )); do
      local est="${estimate_statuses[$diff_i]:-NONE}"
      local strict="${strict_statuses[$diff_i]:-NONE}"
      if [[ "$est" != "$strict" ]]; then
        diff_count=$((diff_count + 1))
      fi
      diff_i=$((diff_i + 1))
    done
    echo "[PROBE][STRICT] status_diff_count_vs_estimate=$diff_count"
  fi

  if [[ -n "$probe_json_path" ]]; then
    local probe_json_abs=""
    probe_json_abs="$(python3 - "$probe_json_path" <<'PY'
from pathlib import Path
import os
import sys

p = Path(os.path.expanduser(sys.argv[1]))
if not p.is_absolute():
    p = Path.cwd() / p
print(p.resolve())
PY
)"

    python3 - \
      "$probe_json_abs" \
      "$TARGET_ROOT" \
      "$ROOT_SOURCE" \
      "$ROOT_INPUT_ABS" \
      "$codex_home" \
      "$max_bytes" \
      "$total_candidate_bytes" \
      "$estimated_loaded_bytes" \
      "$global_hit_label" \
      "$probe_order_tmp" \
      "$probe_dirs_tmp" \
      "$probe_entries_tmp" \
      "$STRICT_SIM" \
      "$strict_separator_bytes" \
      "$strict_candidate_total_bytes" \
      "$strict_estimated_loaded_bytes" \
      "$strict_truncated" \
      "$probe_strict_entries_tmp" \
      "$VERIFY_WITH_CODEX" \
      "$verify_status" \
      "$verify_reason" \
      "$verify_root_exit" \
      "$verify_scan_exit" \
      "$verify_root_output_tmp" \
      "$verify_scan_output_tmp" <<'PY'
from datetime import datetime, timezone
from pathlib import Path
import json
import sys

out_path = Path(sys.argv[1])
target_root = sys.argv[2]
root_source = sys.argv[3]
scan_start_path = sys.argv[4]
codex_home = sys.argv[5]
project_doc_max_bytes = int(sys.argv[6])
candidate_total_bytes = int(sys.argv[7])
estimated_loaded_bytes = int(sys.argv[8])
global_hit = sys.argv[9]
order_file = Path(sys.argv[10])
dirs_file = Path(sys.argv[11])
entries_file = Path(sys.argv[12])
strict_sim = int(sys.argv[13])
strict_separator_bytes = int(sys.argv[14])
strict_candidate_total_bytes = int(sys.argv[15])
strict_estimated_loaded_bytes = int(sys.argv[16])
strict_truncated = bool(int(sys.argv[17]))
strict_entries_file = Path(sys.argv[18])
verify_enabled = bool(int(sys.argv[19]))
verify_status = sys.argv[20]
verify_reason = sys.argv[21]
verify_root_exit = int(sys.argv[22])
verify_scan_exit = int(sys.argv[23])
verify_root_output_file = Path(sys.argv[24])
verify_scan_output_file = Path(sys.argv[25])

delim = "\x1f"

def read_lines(path: Path):
    if not path.exists():
        return []
    return [line.rstrip("\n") for line in path.read_text(encoding="utf-8").splitlines()]

candidate_order = [line for line in read_lines(order_file) if line]

directory_hits = []
for line in read_lines(dirs_file):
    if not line:
        continue
    parts = line.split(delim, 1)
    if len(parts) != 2:
        continue
    directory_hits.append(
        {
            "directory": parts[0],
            "hit": parts[1],
        }
    )

load_estimate = []
for line in read_lines(entries_file):
    if not line:
        continue
    parts = line.split(delim)
    if len(parts) != 5:
        continue
    scope, file_name, path, size_bytes, status = parts
    load_estimate.append(
        {
            "scope": scope,
            "file_name": file_name,
            "path": path,
            "size_bytes": int(size_bytes),
            "status": status,
        }
    )

strict_load_estimate = []
for line in read_lines(strict_entries_file):
    if not line:
        continue
    parts = line.split(delim)
    if len(parts) != 6:
        continue
    scope, file_name, path, size_bytes, separator_bytes_before, status = parts
    strict_load_estimate.append(
        {
            "scope": scope,
            "file_name": file_name,
            "path": path,
            "size_bytes": int(size_bytes),
            "separator_bytes_before": int(separator_bytes_before),
            "status": status,
        }
    )

strict_status_diff = []
for idx, item in enumerate(load_estimate):
    strict_status = strict_load_estimate[idx]["status"] if idx < len(strict_load_estimate) else "NONE"
    if item["status"] != strict_status:
        strict_status_diff.append(
            {
                "path": item["path"],
                "estimate_status": item["status"],
                "strict_status": strict_status,
            }
        )

def read_text_with_limit(path: Path, max_chars: int = 12000):
    if not path.exists():
        return ""
    text = path.read_text(encoding="utf-8", errors="replace")
    if len(text) > max_chars:
        text = text[:max_chars] + f"\n\n[TRUNCATED to {max_chars} chars]"
    return text

report = {
    "generated_at": datetime.now(timezone.utc).isoformat(),
    "target_root": target_root,
    "root_source": root_source,
    "scan_start_path": scan_start_path,
    "codex_home": codex_home,
    "project_doc_max_bytes": project_doc_max_bytes,
    "global_hit": global_hit,
    "candidate_order_per_directory": candidate_order,
    "directory_hits": directory_hits,
    "load_estimate": load_estimate,
    "candidate_total_bytes": candidate_total_bytes,
    "estimated_loaded_bytes": estimated_loaded_bytes,
    "truncated": candidate_total_bytes > project_doc_max_bytes,
    "strict_simulation": {
        "enabled": bool(strict_sim),
        "separator_bytes_between_docs": strict_separator_bytes if strict_sim else None,
        "candidate_total_bytes": strict_candidate_total_bytes if strict_sim else None,
        "estimated_loaded_bytes": strict_estimated_loaded_bytes if strict_sim else None,
        "truncated": strict_truncated if strict_sim else None,
        "load_estimate": strict_load_estimate if strict_sim else [],
        "status_diff_vs_estimate": strict_status_diff if strict_sim else [],
    },
    "codex_verification": {
        "enabled": verify_enabled,
        "status": verify_status,
        "reason": verify_reason,
        "root_probe_exit_code": verify_root_exit,
        "scan_probe_exit_code": verify_scan_exit,
        "root_probe_output": read_text_with_limit(verify_root_output_file) if verify_enabled else "",
        "scan_probe_output": read_text_with_limit(verify_scan_output_file) if verify_enabled else "",
    },
}

out_path.parent.mkdir(parents=True, exist_ok=True)
out_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
    echo "[PROBE] JSON report written: $probe_json_abs"
    rm -f "$probe_entries_tmp" "$probe_strict_entries_tmp" "$probe_dirs_tmp" "$probe_order_tmp"
    if [[ "$verify_root_output_tmp" != "/dev/null" ]]; then
      rm -f "$verify_root_output_tmp"
    fi
    if [[ "$verify_scan_output_tmp" != "/dev/null" ]]; then
      rm -f "$verify_scan_output_tmp"
    fi
  fi

  if [[ "$verify_root_output_tmp" != "/dev/null" ]]; then
    rm -f "$verify_root_output_tmp"
  fi
  if [[ "$verify_scan_output_tmp" != "/dev/null" ]]; then
    rm -f "$verify_scan_output_tmp"
  fi
}

write_with_policy() {
  local target_path="$1"
  local content="$2"
  local label="$3"

  if [[ -f "$target_path" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
      cp "$target_path" "${target_path}.bak.${TIMESTAMP}"
      printf '%s\n' "$content" > "$target_path"
      echo "[OK] Overwrote $label with backup: ${target_path}.bak.${TIMESTAMP}"
    else
      echo "[SKIP] $label already exists: $target_path"
    fi
  else
    printf '%s\n' "$content" > "$target_path"
    echo "[OK] Created $label: $target_path"
  fi
}

upsert_agents_block() {
  local agents_path="$1"
  local mode=""
  mode="$(python3 - "$agents_path" "$BASELINE_START" "$BASELINE_END" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
start = sys.argv[2]
end = sys.argv[3]
block = """<!-- CODEX-BASELINE:START -->
## Codex Baseline

### Project Context
- Repo structure and key modules

### Commands
- Install:
- Dev:
- Lint:
- Type-check:
- Test:
- Build:

### Engineering Conventions
- Naming, architecture, error handling rules

### Safety Constraints
- Secret management
- Destructive command policy

### Definition of Done
- Required checks and acceptance criteria
<!-- CODEX-BASELINE:END -->"""

text = path.read_text(encoding="utf-8")

if start in text and end in text and text.index(start) < text.index(end):
    s = text.index(start)
    e = text.index(end) + len(end)
    head = text[:s].rstrip()
    tail = text[e:].lstrip("\n")
    merged = []
    if head:
        merged.append(head)
    merged.append(block)
    if tail:
        merged.append(tail)
    out = "\n\n".join(merged).rstrip() + "\n"
    mode = "updated"
else:
    if text:
        if text.endswith("\n"):
            out = text + "\n" + block + "\n"
        else:
            out = text + "\n\n" + block + "\n"
    else:
        out = block + "\n"
    mode = "appended"

path.write_text(out, encoding="utf-8")
print(mode)
PY
)"
  if [[ "$mode" == "updated" ]]; then
    echo "[OK] Updated Codex baseline block in AGENTS.md: $agents_path"
  else
    echo "[OK] Appended Codex baseline block to AGENTS.md: $agents_path"
  fi
}

AGENTS_TEMPLATE="$(cat <<'EOF'
# AGENTS.md

<!-- CODEX-BASELINE:START -->
## Codex Baseline

### Project Context
- Repo structure and key modules

### Commands
- Install:
- Dev:
- Lint:
- Type-check:
- Test:
- Build:

### Engineering Conventions
- Naming, architecture, error handling rules

### Safety Constraints
- Secret management
- Destructive command policy

### Definition of Done
- Required checks and acceptance criteria
<!-- CODEX-BASELINE:END -->
EOF
)"

CONFIG_TEMPLATE="$(cat <<'EOF'
# Repository-level Codex defaults

model_reasoning_effort = "medium"
approval_policy = "on-request"
sandbox_mode = "workspace-write"
EOF
)"

echo "[INFO] Target root: $TARGET_ROOT ($ROOT_SOURCE)"
if [[ "$FORCE" -eq 1 ]]; then
  echo "[WARN] --force enabled: existing files will be overwritten with backup."
fi
if [[ "$PROBE" -eq 1 ]]; then
  probe_instruction_chain
fi

if [[ -f "$AGENTS_PATH" ]]; then
  if [[ "$FORCE" -eq 1 ]]; then
    write_with_policy "$AGENTS_PATH" "$AGENTS_TEMPLATE" "AGENTS.md"
  elif [[ "$APPEND_BLOCK" -eq 1 ]]; then
    upsert_agents_block "$AGENTS_PATH"
  else
    echo "[SKIP] AGENTS.md already exists: $AGENTS_PATH"
  fi
else
  write_with_policy "$AGENTS_PATH" "$AGENTS_TEMPLATE" "AGENTS.md"
fi

write_with_policy "$CONFIG_PATH" "$CONFIG_TEMPLATE" ".codex/config.toml"

echo "[NEXT] Review generated content and replace placeholders with project-specific commands."
echo "[NEXT] Run smoke checks:"
echo "       codex --ask-for-approval never \"Summarize the current instructions.\""
echo "       codex --cd <target-subdir> --ask-for-approval never \"Show which instruction files are active.\""
