---
name: code-review-orchestrator
description: This skill should be used when the user asks to "review code", "do a code review", "review my branch", "review MR !1234", "review PR #567", "review feature/auth branch", "review feature/auth vs dev", "check code quality", or wants to orchestrate multiple code review skills/subagents. Coordinates parallel code reviews using multiple review skills and generates comprehensive summary reports.
version: 0.1.0
---

# Code Review Orchestrator

Orchestrate comprehensive code reviews by coordinating multiple review skills and subagents in parallel, then consolidate findings into actionable reports.

## Purpose

This skill manages the complete code review workflow:
- Collect and organize code content for review (diffs, commits, branches, MR/PR info)
- Coordinate multiple subagents using different review skills
- Consolidate individual review reports into comprehensive summaries
- Help users identify and fix issues

## When to Use

Trigger this skill when users request code review with phrases like:
- "Review my code"
- "Review feature/auth branch"
- "Review MR !1234" / "Review PR #567"
- "Review feature/auth vs dev branch"
- "Do a comprehensive code review"

## Workflow

### Step 1: Determine Review Scope

Identify what code to review based on user input:

**Review Sources:**
- **Branch**: Single branch (e.g., `feature/auth`) - review all changes in branch
- **Branch Comparison**: Branch A vs Branch B (e.g., `feature/auth` vs `dev`) - **IMPORTANT**: Find merge base and diff from merge base to branch A's HEAD
- **MR/PR**: Merge Request (GitLab) or Pull Request (GitHub) by number or URL
- **Project**: Monorepo with multiple subprojects - ask which to review

**Required Information:**
- Branch names (if comparing branches)
- MR/PR number or URL
- Project paths (for monorepos)
- Repository URL (if not current directory)

### Step 2: Establish Working Directory

Ask user for working directory with default: `{project_root}/reviews/{review_name}`

**Example:**
- Project: `/home/user/myapp`
- Review topic: `auth-feature`
- Working directory: `/home/user/myapp/reviews/auth-feature`

**Directory Structure:**
```
reviews/{review_name}/
├── code-context.json          # All review metadata
├── diff.patch                  # Git diff output
├── commits.json                # Commit history
├── branch-info.json            # Branch details
├── reports/                    # Individual skill reports
│   ├── skill1-report.md
│   ├── skill2-report.md
│   └── ...
└── {review_name}-summary.md    # Final consolidated report
```

### Step 3: Collect and Save Code Content

Collect comprehensive review information and save to working directory:

**Use `scripts/collect-review-data.sh`** to automate data collection.

**Save as `code-context.json`:**
```json
{
  "review_type": "branch_comparison|branch|mr|pr",
  "source_branch": "feature/auth",
  "target_branch": "dev",
  "merge_base": "abc123",
  "mr_number": "!1234",
  "pr_number": "567",
  "repository": "git@gitlab.com:group/project.git",
  "project_path": "/path/to/project",
  "working_directory": "/path/to/reviews/auth-feature",
  "timestamp": "2025-01-28T10:00:00Z"
}
```

**Save as `diff.patch`:**
- Use `git diff merge_base...source_branch` for branch comparison
- Use `git diff dev...feature/auth` format (three dots) for correct merge base
- Include full context for review

**Save as `commits.json`:**
```json
{
  "commits": [
    {
      "hash": "def456",
      "author": "John Doe",
      "date": "2025-01-28T09:00:00Z",
      "message": "Add login form",
      "files_changed": ["src/auth/login.js"]
    }
  ]
}
```

**Save as `branch-info.json`:**
```json
{
  "source_branch": {
    "name": "feature/auth",
    "head_commit": "def456",
    "is_merged": false
  },
  "target_branch": {
    "name": "dev",
    "head_commit": "abc123"
  }
}
```

**Critical for Branch Comparison:**
When comparing branch A vs branch B:
1. Find merge base: `git merge-base A B`
2. Diff from merge base to A: `git diff merge_base...A`
3. This ensures only unique changes in A are reviewed

### Step 4: Discover Available Review Skills

Identify which code review skills are available in the current environment.

**Check available skills:**
- `code-review:code-review` - General code review
- `superpowers:code-reviewer` - Post-development review against plan
- Project-specific review skills (custom)
- Language-specific linters/checkers

**Present options to user:**
```
Available review skills:
1. code-review:code-review - General quality review
2. security-analyzer - Security vulnerability check
3. performance-checker - Performance analysis
4. style-enforcer - Code style consistency

Which skills would you like to use? (Select multiple)
```

### Step 5: Launch Parallel Subagents

**Use Task tool with run_in_background=true** to launch multiple subagents in parallel.

**Example parallel launch:**
```
Launch subagent 1: Using code-review:code-review skill
Launch subagent 2: Using security-analyzer skill
Launch subagent 3: Using performance-checker skill
```

**Provide each subagent with:**
- Location of `code-context.json`
- Location of `diff.patch`
- Output report path: `reports/{skill-name}-report.md`
- Skill-specific instructions

**Wait for all subagents to complete** before proceeding.

### Step 6: Generate Consolidated Summary

**Read all individual reports** from `reports/` directory.

**Analyze findings and categorize by severity:**
- **Critical**: Security vulnerabilities, crashes, data loss risks
- **High**: Major bugs, performance issues, breaking changes
- **Medium**: Code smells, maintainability issues
- **Low**: Style issues, minor optimizations

**Create `{review_name}-summary.md`:**

**Structure:**
```markdown
# Code Review Summary: {review_name}

## Overview
- Review Type: Branch comparison (feature/auth vs dev)
- Commits: 5 commits
- Files changed: 12 files
- Reviewers: 3 skills
- Date: 2025-01-28

## Findings Summary
- Critical: 2 issues
- High: 5 issues
- Medium: 8 issues
- Low: 3 issues

## Critical Issues

### 1. SQL Injection Risk in auth/login.js
- **Location**: `src/auth/login.js:45`
- **Severity**: Critical
- **Found by**: security-analyzer
- **Issue**: User input directly concatenated into SQL query
- **Recommendation**: Use parameterized queries
- **Code snippet**:
  ```javascript
  // Current (unsafe)
  const query = `SELECT * FROM users WHERE name = '${username}'`

  // Suggested (safe)
  const query = 'SELECT * FROM users WHERE name = ?'
  db.query(query, [username])
  ```

### 2. ...

## High Priority Issues

### 1. Missing Error Handling in API client
- **Location**: `src/api/client.js:78`
- **Severity**: High
- **Found by**: code-review:code-review
- **Issue**: No try-catch around fetch request
- **Recommendation**: Add error handling with retry logic

## Medium Priority Issues

### 1. Inconsistent Naming Convention
- **Location**: Multiple files
- **Severity**: Medium
- **Found by**: style-enforcer
- **Issue**: Mix of camelCase and snake_case
- **Recommendation**: Standardize on camelCase

## Low Priority Issues

### 1. Unused Imports
- **Location**: `src/utils/helpers.js:3`
- **Severity**: Low
- **Issue**: Import 'lodash' unused
- **Recommendation**: Remove unused imports

## Detailed Reports

Individual skill reports:
- [security-analyzer report](reports/security-analyzer-report.md)
- [code-review report](reports/code-review-report.md)
- [performance-checker report](reports/performance-checker-report.md)
```

### Step 7: Interactive Issue Resolution

**After generating summary, present actionable next steps:**

```
Found 18 issues. Which issues would you like to fix?

Options:
1. Fix all Critical issues (2)
2. Fix all High priority issues (5)
3. Fix specific issues (select by number)
4. Review specific issues first
5. Skip fixing for now

Enter your choice:
```

**If user chooses to fix issues:**
- Use appropriate development skills (e.g., `feature-dev:feature-dev`)
- Create implementation plan for fixes
- Apply fixes with user confirmation
- Verify fixes don't introduce new issues

## Additional Resources

### Scripts

- **`scripts/collect-review-data.sh`** - Automates collection of diff, commits, branch info
- **`scripts/find-merge-base.sh`** - Finds merge base for branch comparison
- **`scripts/launch-subagents.sh`** - Launches parallel review subagents

### References

- **`references/subagent-coordination.md`** - Detailed guide on coordinating multiple subagents
- **`references/report-formatting.md`** - Report structure and formatting standards
- **`references/issue-categories.md`** - Issue classification and severity guidelines

### Examples

- **`examples/review-session-output/`** - Complete example of a review session
- **`examples/code-context-example.json`** - Sample code context file
- **`examples/summary-example.md`** - Sample consolidated summary

## Best Practices

### Branch Comparison

**Always use three-dot diff** (`git diff A...B`) for branch comparison:
- `git diff dev...feature/auth` - Changes since branches diverged
- NOT `git diff dev feature/auth` - Changes between branch heads (wrong)

**Example:**
```bash
# Find merge base
MERGE_BASE=$(git merge-base dev feature/auth)

# Diff from merge base to feature branch
git diff $MERGE_BASE...feature/auth > diff.patch
```

### Parallel Subagent Execution

**Launch subagents in parallel** using Task tool with `run_in_background=true`:
```yaml
subagent_type: general-purpose
run_in_background: true
prompt: |
  Review the code in /path/to/diff.patch
  Use the code-review:code-review skill
  Output report to /path/to/reports/code-review-report.md
```

**Wait for completion** using TaskOutput tool before generating summary.

### Report Consolidation

**Read all reports** before generating summary:
- Use Read tool to load each report
- Extract findings with severity levels
- Cross-reference duplicate findings
- Prioritize by severity

**Categorize issues** using severity guidelines in `references/issue-categories.md`.

### User Interaction

**Ask before making changes**:
- Present issues in prioritized list
- Let user choose which to fix
- Confirm each fix before applying
- Provide rollback options

## Troubleshooting

### No Diff Output

**Problem**: Empty `diff.patch` file

**Solutions:**
- Verify branch names are correct
- Check merge base calculation
- Ensure branches have diverged
- Use `git log --oneline A..B` to verify commits exist

### Subagent Failures

**Problem**: Subagent crashes or times out

**Solutions:**
- Check subagent logs for errors
- Verify skill is available
- Reduce scope (fewer files)
- Increase timeout limits

### Duplicate Findings

**Problem**: Multiple skills report same issue

**Solutions:**
- Group by file and line number
- Cite all skills that found it
- Consolidate into single finding
- Note which found it first

## Technical Notes

### Git Diff Formats

- **Two dots (`git diff A..B`)**: Diff between A and B tips
- **Three dots (`git diff A...B`)**: Diff from merge base to B (correct for review)
- **Use three dots** for branch comparison reviews

### Subagent Communication

- Each subagent works independently
- No inter-subagent communication needed
- Consolidation happens after all complete
- Use file system for data sharing

### Performance Considerations

- Large diffs (>10,000 lines): Consider splitting
- Many files (>100): Review in batches
- Many subagents (>5): Limit parallelism
- Cache results for repeated reviews
