#!/usr/bin/env bash
set -euo pipefail

IMAGE="${CONSURF_IMAGE:-noatgnu/consurf-alone:bookworm}"
ALGORITHM="HMMER"
ALIGN="MAFFT"
MODEL="BEST"
MAX_HOMOLOGS="150"
MAX_ID="95"
MIN_ID="35"
ITERATIONS="1"
CUTOFF="0.0001"
NUC=""
ML=""
CLOSEST=""
SEQ=""
DB=""
MSA=""
QUERY=""
TREE=""
STRUCTURE=""
CHAIN=""
CIF=""
OUTDIR=""

usage() {
  cat <<EOF
Usage: $(basename "$0") -s <seq.fasta> -o <output_dir> [options]

Required (one of):
  -s <file>        Query sequence FASTA file
  -m <file>        Pre-computed MSA file (skips search step)

Required:
  -o <dir>         Output directory (created if absent)

Search options:
  -d <file>        Database file (FASTA for HMMER; indexed path for BLAST/MMseqs2)
  -a <algorithm>   HMMER | BLAST | MMseqs2  (default: $ALGORITHM)
  -i <n>           Search iterations         (default: $ITERATIONS)
  -e <cutoff>      E-value cutoff            (default: $CUTOFF)
  -H <n>           Max homologs              (default: $MAX_HOMOLOGS)
  -x <n>           Max %ID                   (default: $MAX_ID)
  -n <n>           Min %ID                   (default: $MIN_ID)
  --closest        Select closest homologs instead of sampling

Alignment options:
  -A <program>     MAFFT | CLUSTALW | PRANK | MUSCLE (default: $ALIGN)
  --msa-query <n>  Query name in MSA (when using -m)

Evolution options:
  -M <model>       BEST | JTT | LG | WAG | Dayhoff | mtREV | cpREV
                   Nucleotide: BEST | T92 | HKY | GTR | JC  (default: $MODEL)
  --ml             Use Maximum Likelihood instead of Bayesian
  --nuc            Nucleotide mode (default: amino acid)

Structure options:
  -p <file>        PDB/mmCIF structure file
  -c <chain>       PDB chain
  --cif            Structure is in mmCIF format

  -t <file>        Tree file
  -I <image>       Docker image (default: $IMAGE)
  -h               Show this help
EOF
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -s) SEQ="$2"; shift 2 ;;
    -o) OUTDIR="$2"; shift 2 ;;
    -d) DB="$2"; shift 2 ;;
    -a) ALGORITHM="$2"; shift 2 ;;
    -A) ALIGN="$2"; shift 2 ;;
    -m) MSA="$2"; shift 2 ;;
    --msa-query) QUERY="$2"; shift 2 ;;
    -t) TREE="$2"; shift 2 ;;
    -p) STRUCTURE="$2"; shift 2 ;;
    -c) CHAIN="$2"; shift 2 ;;
    -M) MODEL="$2"; shift 2 ;;
    -i) ITERATIONS="$2"; shift 2 ;;
    -e) CUTOFF="$2"; shift 2 ;;
    -H) MAX_HOMOLOGS="$2"; shift 2 ;;
    -x) MAX_ID="$2"; shift 2 ;;
    -n) MIN_ID="$2"; shift 2 ;;
    -I) IMAGE="$2"; shift 2 ;;
    --nuc) NUC="--Nuc"; shift ;;
    --ml) ML="--Maximum_Likelihood"; shift ;;
    --closest) CLOSEST="--closest"; shift ;;
    --cif) CIF="--cif"; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

[[ -z "$OUTDIR" ]] && { echo "Error: -o <output_dir> is required"; usage; }
[[ -z "$SEQ" && -z "$MSA" ]] && { echo "Error: -s <seq> or -m <msa> is required"; usage; }

mkdir -p "$OUTDIR"
OUTDIR="$(realpath "$OUTDIR")"

MOUNTS=(-v "$OUTDIR:/output")
CMD_ARGS=(--dir /output --algorithm "$ALGORITHM" --align "$ALIGN" --model "$MODEL"
          --iterations "$ITERATIONS" --cutoff "$CUTOFF"
          --MAX_HOMOLOGS "$MAX_HOMOLOGS" --MAX_ID "$MAX_ID" --MIN_ID "$MIN_ID")

MOUNT_RESULT=""
mount_file() {
  local host_path container_dir
  host_path="$(realpath "$1")"
  container_dir="/input/$(echo "$host_path" | md5sum | cut -c1-8)"
  MOUNTS+=(-v "$(dirname "$host_path"):$container_dir:ro")
  MOUNT_RESULT="$container_dir/$(basename "$host_path")"
}

if [[ -n "$SEQ" ]]; then
  mount_file "$SEQ"
  CMD_ARGS+=(--seq "$MOUNT_RESULT")
fi

if [[ -n "$MSA" ]]; then
  mount_file "$MSA"
  CMD_ARGS+=(--msa "$MOUNT_RESULT")
  [[ -n "$QUERY" ]] && CMD_ARGS+=(--query "$QUERY")
fi

if [[ -n "$DB" ]]; then
  DB_REAL="$(realpath "$DB")"
  DB_DIR="$(dirname "$DB_REAL")"
  DB_BASE="$(basename "$DB_REAL")"
  MOUNTS+=(-v "$DB_DIR:/db:ro")
  CMD_ARGS+=(--DB "/db/$DB_BASE")
fi

if [[ -n "$TREE" ]]; then
  mount_file "$TREE"
  CMD_ARGS+=(--tree "$MOUNT_RESULT")
fi

if [[ -n "$STRUCTURE" ]]; then
  mount_file "$STRUCTURE"
  CMD_ARGS+=(--structure "$MOUNT_RESULT")
  [[ -n "$CHAIN" ]] && CMD_ARGS+=(--chain "$CHAIN")
  [[ -n "$CIF" ]] && CMD_ARGS+=($CIF)
fi

[[ -n "$NUC" ]]     && CMD_ARGS+=($NUC)
[[ -n "$ML" ]]      && CMD_ARGS+=($ML)
[[ -n "$CLOSEST" ]] && CMD_ARGS+=($CLOSEST)

echo "Running ConSurf via $IMAGE"
echo "Output: $OUTDIR"
echo ""

docker run --rm "${MOUNTS[@]}" "$IMAGE" \
  python /workspace/stand_alone_consurf/stand_alone_consurf.py "${CMD_ARGS[@]}"
