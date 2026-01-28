#!/bin/bash

###############################################################################
# launch-subagents.sh
#
# Utility script to help launch multiple subagents for parallel code review.
# This is a helper reference - actual subagent launch is done via Task tool.
#
# Usage:
#   ./launch-subagents.sh [OPTIONS]
#
# Options:
#   -w, --workdir DIR       Working directory (required)
#   -s, --skills SKILLS     Comma-separated list of skills to use
#   -t, --timeout SECONDS   Timeout per subagent (default: 300)
#   -h, --help              Show this help message
#
# Example:
#   ./launch-subagents.sh -w ./reviews/auth-feature \
#     -s "security-analyzer,code-review,performance-checker"
#
###############################################################################

set -e
set -u
set -o pipefail

###############################################################################
# Colors
###############################################################################
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

###############################################################################
# Default values
###############################################################################
WORKDIR=""
SKILLS=""
TIMEOUT=300

###############################################################################
# Helper functions
###############################################################################

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Subagent Launcher Reference${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generates Task tool commands for launching parallel review subagents.

Options:
  -w, --workdir DIR       Working directory containing review data (required)
  -s, --skills SKILLS     Comma-separated list of skills (e.g., "skill1,skill2")
  -t, --timeout SECONDS   Timeout per subagent in seconds (default: 300)
  -h, --help              Show this help message

Example:
  $(basename "$0") -w ./reviews/auth-feature \\
    -s "security-analyzer,code-review,performance-checker"

Note:
  This script generates Task tool commands that should be used in Claude Code.
  It does not actually launch subagents itself.

EOF
}

###############################################################################
# Parse arguments
###############################################################################

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -w|--workdir)
                WORKDIR="$2"
                shift 2
                ;;
            -s|--skills)
                SKILLS="$2"
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

validate_args() {
    if [ -z "$WORKDIR" ]; then
        echo "Error: Working directory is required (-w|--workdir)"
        exit 1
    fi

    if [ ! -d "$WORKDIR" ]; then
        echo "Error: Working directory does not exist: $WORKDIR"
        exit 1
    fi

    if [ ! -f "$WORKDIR/code-context.json" ]; then
        echo "Error: code-context.json not found in $WORKDIR"
        echo "Run collect-review-data.sh first."
        exit 1
    fi

    if [ ! -f "$WORKDIR/diff.patch" ]; then
        echo "Error: diff.patch not found in $WORKDIR"
        echo "Run collect-review-data.sh first."
        exit 1
    fi
}

###############################################################################
# Generate Task tool commands
###############################################################################

generate_task_commands() {
    local workdir="$1"
    local skills="$2"
    local timeout="$3"

    print_header

    log_info "Working directory: $workdir"
    log_info "Skills: $skills"
    log_info "Timeout: ${timeout}s"
    echo ""

    echo "=========================================="
    echo "Generated Task Tool Commands"
    echo "=========================================="
    echo ""
    echo "Copy and paste these commands into Claude Code:"
    echo ""

    # Convert skills to array
    IFS=',' read -ra SKILL_ARRAY <<< "$skills"

    local index=1
    for skill in "${SKILL_ARRAY[@]}"; do
        # Trim whitespace
        skill=$(echo "$skill" | xargs)

        # Generate report filename
        local report_file="${skill}-report.md"
        if [ "$skill" = "code-review:code-review" ]; then
            report_file="code-review-report.md"
        fi

        echo "=========================================="
        echo "Subagent $index: $skill"
        echo "=========================================="
        echo ""
        echo '```'
        echo "Task("
        echo "  subagent_type=\"general-purpose\","
        echo "  prompt=\"Review the code changes using the $skill skill."
        echo ""
        echo "Review data location:"
        echo "  - Working directory: $workdir"
        echo "  - Diff file: $workdir/diff.patch"
        echo "  - Code context: $workdir/code-context.json"
        echo ""
        echo "Generate a comprehensive review report and save it to:"
        echo "  $workdir/reports/$report_file"
        echo ""
        echo "Your report should include:"
        echo "  1. Summary of changes reviewed"
        echo "  2. Issues found, categorized by severity (Critical, High, Medium, Low)"
        echo "  3. Specific file and line references for each issue"
        echo "  4. Code examples showing current and recommended code"
        echo "  5. Actionable recommendations for fixes"
        echo ""
        echo "Use the report formatting standards from the code-review-orchestrator skill."
        echo "  See references/report-formatting.md for detailed guidelines."
        echo "  See references/issue-categories.md for severity level definitions."
        echo ""
        echo "Format your report as markdown with clear sections and code blocks.\","
        echo "  run_in_background=true"
        echo ")"
        echo '```'
        echo ""
        index=$((index + 1))
    done

    echo "=========================================="
    echo "After Launching Subagents"
    echo "=========================================="
    echo ""
    echo "1. Wait for all subagents to complete"
    echo "2. Check for report files in: $workdir/reports/"
    echo "3. Generate consolidated summary"
    echo ""
    echo "Example to check completion:"
    echo "  ls -la $workdir/reports/"
    echo ""
}

###############################################################################
# Show available skills
###############################################################################

show_available_skills() {
    echo "=========================================="
    echo "Commonly Available Review Skills"
    echo "=========================================="
    echo ""
    echo "Built-in skills:"
    echo "  - code-review:code-review        General code quality review"
    echo "  - superpowers:code-reviewer      Post-development review"
    echo ""
    echo "Common custom skills (if installed):"
    echo "  - security-analyzer              Security vulnerability scanning"
    echo "  - performance-checker            Performance analysis"
    echo "  - style-enforcer                 Code style consistency"
    echo "  - test-coverage-analyzer         Test coverage analysis"
    echo ""
    echo "To see all available skills in your environment, ask Claude:"
    echo "  'List all available skills'"
    echo ""
}

###############################################################################
# Main
###############################################################################

main() {
    parse_args "$@"
    validate_args

    generate_task_commands "$WORKDIR" "$SKILLS" "$TIMEOUT"

    show_available_skills
}

main "$@"
