#!/bin/bash
#
# Run stub tests for nf-carafe-ai-ms.
# Tests the workflow structure and process wiring without pulling containers.
#
# Usage:
#   bash tests/run_stub_tests.sh          # run all stub tests
#   bash tests/run_stub_tests.sh clean    # remove all test artifacts
#
# Each test exercises a different workflow path to ensure all processes and
# subworkflows are correctly wired together.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STUB_CONFIG="$SCRIPT_DIR/stub_test.config"
WORK_DIR="$SCRIPT_DIR/work"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

clean() {
    echo "Cleaning test artifacts..."
    rm -rf "$WORK_DIR"
    rm -rf "$PROJECT_DIR/.nextflow"
    rm -f "$PROJECT_DIR/.nextflow.log"*
    echo "Done."
}

if [ "${1:-}" = "clean" ]; then
    clean
    exit 0
fi

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    shift
    local nf_args=("$@")

    TESTS_RUN=$((TESTS_RUN + 1))
    echo ""
    echo -e "${YELLOW}━━━ Test: ${test_name} ━━━${NC}"

    # Clean work directory for each test
    rm -rf "$WORK_DIR"

    if nextflow run "$PROJECT_DIR/main.nf" \
        -stub \
        -c "$STUB_CONFIG" \
        -work-dir "$WORK_DIR/nf-work" \
        "${nf_args[@]}" 2>&1; then
        echo -e "${GREEN}✓ PASSED: ${test_name}${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ FAILED: ${test_name}${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "========================================"
echo " nf-carafe-ai-ms Stub Tests"
echo "========================================"

# ──────────────────────────────────────────────────────────────────────
# Test 1: Default path (mzML input → DIA-NN → Carafe → diann output)
# Exercises: DIANN_SEARCH_LIB_FREE, CARAFE
# ──────────────────────────────────────────────────────────────────────
run_test "Default path: mzML + DIA-NN + Carafe (diann output)" \
    --spectra_file "$SCRIPT_DIR/data/test.mzML" \
    --carafe_fasta_file "$SCRIPT_DIR/data/test.fasta"

# ──────────────────────────────────────────────────────────────────────
# Test 2: Encyclopedia output format
# Exercises: DIANN_SEARCH_LIB_FREE, CARAFE, ENCYCLOPEDIA_TSV_TO_DLIB
# ──────────────────────────────────────────────────────────────────────
run_test "Encyclopedia output format" \
    --spectra_file "$SCRIPT_DIR/data/test.mzML" \
    --carafe_fasta_file "$SCRIPT_DIR/data/test.fasta" \
    --output_format "encyclopedia"

# ──────────────────────────────────────────────────────────────────────
# Test 3: Pre-computed peptide results (skip DIA-NN)
# Exercises: CARAFE only (DIA-NN is skipped)
# ──────────────────────────────────────────────────────────────────────
run_test "Pre-computed peptide results (skip DIA-NN)" \
    --spectra_file "$SCRIPT_DIR/data/test.mzML" \
    --carafe_fasta_file "$SCRIPT_DIR/data/test.fasta" \
    --peptide_results_file "$SCRIPT_DIR/data/test_peptides.tsv"

# ──────────────────────────────────────────────────────────────────────
# Test 4: Pre-computed peptide results + encyclopedia output
# Exercises: CARAFE, ENCYCLOPEDIA_TSV_TO_DLIB (DIA-NN skipped)
# ──────────────────────────────────────────────────────────────────────
run_test "Pre-computed peptides + encyclopedia output" \
    --spectra_file "$SCRIPT_DIR/data/test.mzML" \
    --carafe_fasta_file "$SCRIPT_DIR/data/test.fasta" \
    --peptide_results_file "$SCRIPT_DIR/data/test_peptides.tsv" \
    --output_format "encyclopedia"

# ──────────────────────────────────────────────────────────────────────
# Test 5: RAW file input (triggers msconvert)
# Exercises: MSCONVERT, DIANN_SEARCH_LIB_FREE, CARAFE
# ──────────────────────────────────────────────────────────────────────
run_test "RAW input (msconvert + DIA-NN + Carafe)" \
    --spectra_file "$SCRIPT_DIR/data/test.raw" \
    --carafe_fasta_file "$SCRIPT_DIR/data/test.fasta"

# ──────────────────────────────────────────────────────────────────────
# Test 6: Separate DIA-NN and Carafe FASTA files
# Exercises: DIANN_SEARCH_LIB_FREE (with separate FASTA), CARAFE
# ──────────────────────────────────────────────────────────────────────
run_test "Separate DIA-NN FASTA file" \
    --spectra_file "$SCRIPT_DIR/data/test.mzML" \
    --carafe_fasta_file "$SCRIPT_DIR/data/test.fasta" \
    --diann_fasta_file "$SCRIPT_DIR/data/test.fasta"

# ──────────────────────────────────────────────────────────────────────
# Test 7: Custom Carafe CLI options
# Exercises: CARAFE with additional CLI options
# ──────────────────────────────────────────────────────────────────────
run_test "Custom Carafe CLI options" \
    --spectra_file "$SCRIPT_DIR/data/test.mzML" \
    --carafe_fasta_file "$SCRIPT_DIR/data/test.fasta" \
    --carafe_cli_options "--custom-option"

# Clean up all test artifacts
clean

# Summary
echo ""
echo "========================================"
echo " Test Summary"
echo "========================================"
echo -e " Total:  ${TESTS_RUN}"
echo -e " Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e " Failed: ${RED}${TESTS_FAILED}${NC}"
echo "========================================"

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
