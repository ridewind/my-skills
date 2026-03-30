# Code Templates for Code Review Executor

This file contains reusable code templates for common operations.

## AskUserQuestion Templates

### Preset Selection
```python
AskUserQuestion(
    questions=[
        {
            "header": "审查预设",
            "multiSelect": False,
            "options": [
                {
                    "label": "快速审查",
                    "description": "轻量级审查，适合日常代码评审"
                },
                {
                    "label": "全面审查",
                    "description": "全面代码审查，包含安全、性能、质量"
                },
                {
                    "label": "安全审计",
                    "description": "专注于安全漏洞和合规性检查"
                }
            ],
            "question": "请选择审查预设："
        }
    ]
)
```

### Review Confirmation
```python
AskUserQuestion(
    questions=[
        {
            "header": "确认审查",
            "multiSelect": False,
            "options": [
                {
                    "label": "继续审查",
                    "description": "开始执行代码审查，启动并行子代理"
                },
                {
                    "label": "取消",
                    "description": "取消本次审查，退出技能"
                }
            ],
            "question": "确认开始审查？"
        }
    ]
)
```

## Task Tool Templates

### Launch Skill Subagent
```xml
<Task
    subagent_type="general-purpose"
    prompt="Review the code changes using the {skill_id} skill.

Review data location:
  - Working directory: {workdir}
  - Diff file: {workdir}/diff.patch
  - Code context: {workdir}/code-context.json

Generate a comprehensive review report and save it to:
  {workdir}/reports/{skill_name}-report.md

Your report should include:
  1. Summary of changes reviewed
  2. Issues found, categorized by severity
  3. Specific file and line references
  4. Actionable recommendations

Format as markdown with clear sections.",
    run_in_background="true"
/>
```

### Launch Command Subagent
```xml
<Task
    subagent_type="general-purpose"
    prompt="Execute the {command_id} command to review code changes.

1. First invoke the skill:
   Skill(skill='{command_id}')

2. After the skill loads, provide it with:
   - Diff file: {workdir}/diff.patch
   - Code context: {workdir}/code-context.json

3. Save the output to: {workdir}/reports/{command_name}-report.md",
    run_in_background="true"
/>
```

## Code Context JSON Template

```json
{
  "review_type": "branch_comparison",
  "source_branch": "feature/auth",
  "target_branch": "dev",
  "repository": "https://github.com/example/project",
  "project_path": "/path/to/project",
  "working_directory": "/path/to/reviews/auth-feature-20260327-1",
  "timestamp": "2026-03-27T10:30:00Z",
  "metadata": {
    "review_name": "auth-feature",
    "reviewer": "code-review-orchestrator",
    "files_changed": 15,
    "lines_added": 350,
    "lines_removed": 120
  },
  "git_diff_info": {
    "diff_file": "diff.patch"
  }
}
```

## Report Summary Template

```markdown
# Code Review Summary: {review_name}

## Executive Summary
{overview of changes and key findings}

## Critical Issues
{list of critical issues with file:line references}

## High Priority Issues
{list of high priority issues}

## Medium Priority Issues
{list of medium priority issues}

## Low Priority Issues
{list of low priority issues}

## Statistics

### Issues by Severity
| Severity | Count |
|----------|-------|
| Critical | X |
| High | X |
| Medium | X |
| Low | X |

### Issues by Reviewer Skill
| Skill | Issues Found |
|-------|--------------|
| {skill1} | X |
| {skill2} | X |

## Detailed Reports
Individual reports: `reports/{skill}-report.md`

## Next Steps
{recommended actions}
```

## Deduplication Logic

```python
def deduplicate_issues(issues):
    """Deduplicate issues by file:line and merge found_by lists."""
    seen = {}
    for issue in issues:
        key = (issue['file'], issue.get('line', 0), issue['type'])
        if key in seen:
            # Merge found_by lists
            seen[key]['found_by'] = list(set(seen[key]['found_by'] + issue['found_by']))
        else:
            seen[key] = issue
    return list(seen.values())
```

## Severity Determination

```python
def determine_severity(issue):
    """Determine issue severity based on type and impact."""
    CRITICAL_PATTERNS = ['sql injection', 'auth bypass', 'rce', 'data leak']
    HIGH_PATTERNS = ['xss', 'csrf', 'missing validation', 'hardcoded secret']

    issue_lower = issue['description'].lower()

    if any(p in issue_lower for p in CRITICAL_PATTERNS):
        return 'Critical'
    elif any(p in issue_lower for p in HIGH_PATTERNS):
        return 'High'
    elif issue.get('impact') == 'functionality':
        return 'Medium'
    else:
        return 'Low'
```
