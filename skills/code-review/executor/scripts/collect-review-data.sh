#!/bin/bash

###############################################################################
# collect-review-data.sh
#
# Collects comprehensive code review data from git repository.
# Supports branch comparison, single branch review, and MR/PR review.
#
# Usage:
#   ./collect-review-data.sh [OPTIONS]
#
# Options:
#   -s, --source BRANCH      Source branch (required)
#   -t, --target BRANCH      Target branch for comparison
#   -m, --mr NUMBER          Merge Request number
#   -p, --pr NUMBER          Pull Request number
#   -o, --output DIR         Output directory (required)
#   -r, --repo URL           Repository URL
#   -n, --name NAME          Review name (default: auto-generated)
#   -h, --help               Show this help message
#
# Examples:
#   # Compare feature/auth to dev
#   ./collect-review-data.sh -s feature/auth -t dev -o ./reviews/auth-feature
#
#   # Review single branch
#   ./collect-review-data.sh -s feature/auth -o ./reviews/auth-branch
#
#   # Review GitLab MR
#   ./collect-review-data.sh -m 1234 -o ./reviews/mr-1234
#
###############################################################################

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

###############################################################################
# Colors for output
###############################################################################
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

###############################################################################
# Default values
###############################################################################
SOURCE_BRANCH=""
TARGET_BRANCH=""
MR_NUMBER=""
PR_NUMBER=""
OUTPUT_DIR=""
REPO_URL=""
REVIEW_NAME=""
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")

###############################################################################
# Helper functions
###############################################################################

print_usage() {
    grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^# //' | sed 's/^#//'
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

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

###############################################################################
# Data collection functions
###############################################################################

collect_repo_info() {
    log_info "Collecting repository information..."

    REPO_URL=$(git config --get remote.origin.url || echo "unknown")
    local current_branch=$(git branch --show-current)

    echo "  Repository: $REPO_URL"
    echo "  Current branch: $current_branch"
}

collect_commit_history() {
    local output_file=$1
    local source=$2
    local target=${3:-""}

    log_info "Collecting commit history..."

    if [ -n "$target" ]; then
        # Branch comparison: commits from merge base to source
        local merge_base=$(git merge-base "$target" "$source")
        git log "$merge_base..$source" --pretty=format:'%H|%an|%ae|%ad|%s' --date=iso > "$output_file"
    else
        # Single branch: recent commits
        git log "$source" -20 --pretty=format:'%H|%an|%ae|%ad|%s' --date=iso > "$output_file"
    fi

    local commit_count=$(wc -l < "$output_file")
    echo "  Found $commit_count commits"
}

generate_diff() {
    local output_file=$1
    local source=$2
    local target=${3:-""}

    log_info "Generating diff..."

    if [ -n "$target" ]; then
        # Branch comparison: diff from merge base to source
        local merge_base=$(git merge-base "$target" "$source")
        log_info "  Using merge base: $merge_base"
        git diff "$merge_base...$source" > "$output_file"
    else
        # Single branch: diff from parent
        git diff "$source^..$source" > "$output_file"
    fi

    local stats=$(git diff --stat "$merge_base...$source" 2>/dev/null || echo "")
    echo "  $stats"
}

collect_branch_info() {
    local output_file=$1
    local source=$2
    local target=${3:-""}

    log_info "Collecting branch information..."

    local source_head=$(git rev-parse "$source")
    local source_msg=$(git log -1 --pretty=%s "$source")
    local source_merged=$(git branch --merged "$source" --contains "$source" 2>/dev/null | grep -v "^\*" | wc -l)

    cat > "$output_file" <<EOF
{
  "source": {
    "name": "$source",
    "head_commit": "$source_head",
    "head_message": "$source_msg",
    "is_merged": $([ "$source_merged" -gt 0 ] && echo "true" || echo "false")
  }
EOF

    if [ -n "$target" ]; then
        local target_head=$(git rev-parse "$target")
        local target_msg=$(git log -1 --pretty=%s "$target")
        local merge_base=$(git merge-base "$target" "$source")

        cat >> "$output_file" <<EOF
,
  "target": {
    "name": "$target",
    "head_commit": "$target_head",
    "head_message": "$target_msg"
  },
  "merge_base": "$merge_base"
EOF
    fi

    echo "}" >> "$output_file"

    echo "  Source: $source ($source_head)"
    if [ -n "$target" ]; then
        echo "  Target: $target ($target_head)"
    fi
}

collect_file_stats() {
    local source=$1
    local target=${2:-""}

    log_info "Collecting file statistics..."

    local merge_base
    if [ -n "$target" ]; then
        merge_base=$(git merge-base "$target" "$source")
    fi

    local files_added=0
    local files_removed=0
    local lines_added=0
    local lines_removed=0

    if [ -n "$target" ]; then
        local stats=$(git diff --numstat "$merge_base...$source")
    else
        local stats=$(git diff --numstat "$source^..$source")
    fi

    echo "$stats" | while read -r added removed file; do
        [ "$added" != "-" ] && lines_added=$((lines_added + added))
        [ "$removed" != "-" ] && lines_removed=$((lines_removed + removed))
    done

    echo "  Files changed: $(echo "$stats" | wc -l)"
    echo "  Lines added: $lines_added"
    echo "  Lines removed: $lines_removed"

    # Return as JSON for code-context.json
    echo "{\"files_changed\": $(echo "$stats" | wc -l | tr -d ' '), \"lines_added\": $lines_added, \"lines_removed\": $lines_removed}"
}

generate_code_context() {
    local output_file=$1
    local source=$2
    local target=${3:-""}
    local stats=$4

    log_info "Generating code context..."

    local review_type
    if [ -n "$target" ]; then
        review_type="branch_comparison"
    else
        review_type="branch"
    fi

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$output_file" <<EOF
{
  "review_type": "$review_type",
  "source_branch": "$source",
  "target_branch": "$target",
  "repository": "$REPO_URL",
  "project_path": "$PROJECT_ROOT",
  "working_directory": "$OUTPUT_DIR",
  "timestamp": "$timestamp",
  "metadata": {
    "review_name": "$REVIEW_NAME",
    "reviewer": "code-review-orchestrator",
    $stats
  },
  "git_diff_info": {
    "diff_file": "diff.patch"
  }
}
EOF

    echo "  Code context saved to: $output_file"
}

###############################################################################
# Main execution
###############################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--source)
                SOURCE_BRANCH="$2"
                shift 2
                ;;
            -t|--target)
                TARGET_BRANCH="$2"
                shift 2
                ;;
            -m|--mr)
                MR_NUMBER="$2"
                shift 2
                ;;
            -p|--pr)
                PR_NUMBER="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -r|--repo)
                REPO_URL="$2"
                shift 2
                ;;
            -n|--name)
                REVIEW_NAME="$2"
                shift 2
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
}

validate_args() {
    if [ -z "$OUTPUT_DIR" ]; then
        log_error "Output directory is required (-o|--output)"
        exit 1
    fi

    if [ -z "$SOURCE_BRANCH" ] && [ -z "$MR_NUMBER" ] && [ -z "$PR_NUMBER" ]; then
        log_error "Must specify source branch (-s), MR number (-m), or PR number (-p)"
        exit 1
    fi

    # Auto-generate review name if not provided
    if [ -z "$REVIEW_NAME" ]; then
        if [ -n "$SOURCE_BRANCH" ]; then
            # Sanitize branch name for directory use
            REVIEW_NAME=$(echo "$SOURCE_BRANCH" | sed 's/\//_/g' | sed 's/^feature_//')
        else
            REVIEW_NAME="review-$(date +%Y%m%d-%H%M%S)"
        fi
    fi
}

create_output_dir() {
    log_info "Creating output directory: $OUTPUT_DIR"
    mkdir -p "$OUTPUT_DIR/reports"
}

main() {
    echo "=========================================="
    echo "  Code Review Data Collector"
    echo "=========================================="
    echo ""

    parse_args "$@"
    validate_args
    check_git_repo

    create_output_dir

    collect_repo_info

    # If MR/PR number provided, fetch branch info
    if [ -n "$MR_NUMBER" ] || [ -n "$PR_NUMBER" ]; then
        log_warn "MR/PR review not yet implemented. Please provide branch names."
        log_warn "Use: -s <source_branch> -t <target_branch>"
        exit 1
    fi

    # Validate branches
    validate_branch "$SOURCE_BRANCH"
    if [ -n "$TARGET_BRANCH" ]; then
        validate_branch "$TARGET_BRANCH"
    fi

    # Collect data
    echo ""
    collect_commit_history "$OUTPUT_DIR/commits.txt" "$SOURCE_BRANCH" "$TARGET_BRANCH"

    generate_diff "$OUTPUT_DIR/diff.patch" "$SOURCE_BRANCH" "$TARGET_BRANCH"

    collect_branch_info "$OUTPUT_DIR/branch-info.json" "$SOURCE_BRANCH" "$TARGET_BRANCH"

    local stats=$(collect_file_stats "$SOURCE_BRANCH" "$TARGET_BRANCH")

    generate_code_context "$OUTPUT_DIR/code-context.json" "$SOURCE_BRANCH" "$TARGET_BRANCH" "$stats"

    # Convert commits.txt to JSON
    if [ -f "$OUTPUT_DIR/commits.txt" ]; then
        log_info "Converting commit history to JSON..."
        python3 -c "
import json
import sys

commits = []
with open('$OUTPUT_DIR/commits.txt', 'r') as f:
    for line in f:
        parts = line.strip().split('|')
        if len(parts) >= 5:
            commits.append({
                'hash': parts[0],
                'author': parts[1],
                'email': parts[2],
                'date': parts[3],
                'message': parts[4]
            })

with open('$OUTPUT_DIR/commits.json', 'w') as f:
    json.dump({'commits': commits}, f, indent=2)
" 2>/dev/null || log_warn "Python3 not found, commits.txt saved instead of commits.json"
    fi

    echo ""
    log_info "Data collection complete!"
    echo ""
    echo "Generated files:"
    echo "  - $OUTPUT_DIR/code-context.json"
    echo "  - $OUTPUT_DIR/diff.patch"
    echo "  - $OUTPUT_DIR/commits.txt (or commits.json)"
    echo "  - $OUTPUT_DIR/branch-info.json"
    echo ""
    log_info "Ready for code review!"
}

main "$@"
