#!/bin/bash

###############################################################################
# find-merge-base.sh
#
# Finds the merge base (common ancestor) between two branches.
# Essential for correctly comparing branches in code reviews.
#
# Usage:
#   ./find-merge-base.sh BRANCH_A BRANCH_B
#
# Output:
#   Prints the merge base commit hash
#   Exits with 0 if found, 1 if error
#
# Example:
#   $ ./find-merge-base.sh feature/auth dev
#   abc123def456...
#
###############################################################################

set -e
set -u
set -o pipefail

###############################################################################
# Colors
###############################################################################
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

###############################################################################
# Helper functions
###############################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

###############################################################################
# Functions
###############################################################################

check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        log_error "Not a git repository"
        exit 1
    fi
}

validate_branch() {
    local branch=$1
    if ! git rev-parse --verify "$branch" > /dev/null 2>&1; then
        log_error "Branch '$branch' does not exist"
        exit 1
    fi
}

find_merge_base() {
    local branch_a=$1
    local branch_b=$2

    # Find merge base using git merge-base
    local merge_base
    merge_base=$(git merge-base "$branch_a" "$branch_b" 2>&1)

    if [ $? -ne 0 ]; then
        log_error "Failed to find merge base: $merge_base"
        exit 1
    fi

    if [ -z "$merge_base" ]; then
        log_error "No common ancestor found between '$branch_a' and '$branch_b'"
        exit 1
    fi

    echo "$merge_base"
}

print_merge_base_info() {
    local branch_a=$1
    local branch_b=$2
    local merge_base=$3

    echo ""
    echo "Merge Base Information:"
    echo "======================="
    echo "Branch A:      $branch_a"
    echo "Branch B:      $branch_b"
    echo "Merge Base:    $merge_base"
    echo ""

    # Get commit info
    local commit_info=$(git log -1 --format="%h - %an (%ar): %s" "$merge_base")
    echo "Commit Info:   $commit_info"
    echo ""

    # Show visualization
    log_info "Branch visualization:"
    git log --graph --oneline --decorate --all --simplify-by-decoration \
        --ancestry-path "$merge_base..$branch_a" "$merge_base..$branch_b" 2>/dev/null || {
        log_warn "Could not generate graph (branches may have diverged significantly)"
    }

    echo ""
    log_info "Diff command for review:"
    echo "  git diff $merge_base...$branch_a"
    echo ""
}

###############################################################################
# Main
###############################################################################

show_usage() {
    cat << EOF
Usage: $(basename "$0") BRANCH_A BRANCH_B

Finds the merge base (common ancestor) between two branches.

Arguments:
  BRANCH_A    First branch name
  BRANCH_B    Second branch name

Output:
  Prints the merge base commit hash to stdout

Example:
  $ $(basename "$0") feature/auth dev
  abc123def4567890

EOF
}

main() {
    # Check if help requested
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        show_usage
        exit 0
    fi

    # Validate arguments
    if [ $# -ne 2 ]; then
        log_error "Invalid arguments"
        show_usage
        exit 1
    fi

    local branch_a=$1
    local branch_b=$2

    # Check git repository
    check_git_repo

    # Validate branches
    validate_branch "$branch_a"
    validate_branch "$branch_b"

    # Find merge base
    local merge_base
    merge_base=$(find_merge_base "$branch_a" "$branch_b")

    # Print merge base (for script usage)
    echo "$merge_base"

    # Print detailed info (for human usage)
    print_merge_base_info "$branch_a" "$branch_b" "$merge_base"
}

main "$@"
