# Subagent Coordination Guide

Detailed guide on coordinating multiple subagents for parallel code review execution.

## Overview

The code review orchestrator coordinates multiple subagents to review code in parallel, each using a different review skill. This guide covers the technical implementation details.

## Launching Subagents

### Using the Task Tool

Launch subagents in parallel using the Task tool with `run_in_background=true`:

**Basic Pattern:**
```
Task(
  subagent_type="general-purpose",
  prompt="Review code using specific skill, output report to specific path",
  run_in_background=true
)
```

**Launch Multiple in Parallel:**

Send multiple Task tool calls in a single message to launch simultaneously:

```xml
<tool_use>
<tool_name>Task</tool_name>
<parameters>
  <subagent_type>general-purpose</subagent_type>
  <prompt>Review the code in /path/to/diff.patch using the code-review:code-review skill. Output your report to /path/to/reports/code-review-report.md</prompt>
  <run_in_background>true</run_in_background>
</parameters>
</tool_use>

<tool_use>
<tool_name>Task</tool_name>
<parameters>
  <subagent_type>general-purpose</subagent_type>
  <prompt>Review the code in /path/to/diff.patch using the security-analyzer skill. Output your report to /path/to/reports/security-report.md</prompt>
  <run_in_background>true</run_in_background>
</parameters>
</tool_use>
```

### Subagent Prompt Structure

Each subagent prompt should include:

**Required Information:**
- Code location (diff file, code-context.json)
- Skill to use
- Output report path
- Expected report format

**Example Prompt:**
```
You are a code reviewer. Review the code changes in the following diff:

Diff file location: /path/to/reviews/auth-feature/diff.patch
Code context: /path/to/reviews/auth-feature/code-context.json

Use the code-review:code-review skill to analyze the code.

Output your review report to: /path/to/reviews/auth-feature/reports/code-review-report.md

Your report should include:
1. Summary of changes
2. Issues found categorized by severity (Critical, High, Medium, Low)
3. Specific file and line references
4. Code examples for issues found
5. Recommendations for fixes
```

## Monitoring Subagent Progress

### Using TaskOutput Tool

Check subagent completion status:

```xml
<tool_use>
<tool_name>TaskOutput</tool_name>
<parameters>
  <task_id>agent_id_from_task_launch</task_id>
  <block>true</block>
  <timeout>300000</timeout>
</parameters>
</tool_use>
```

**Parameters:**
- `task_id`: ID returned from Task tool
- `block`: true = wait for completion, false = check status only
- `timeout`: Max wait time in milliseconds

### Polling Strategy

For non-blocking checks, use `block=false`:

```xml
<tool_use>
<tool_name>TaskOutput</tool_name>
<parameters>
  <task_id>agent_id_1</task_id>
  <block>false</block>
  <timeout>5000</timeout>
</parameters>
</tool_use>

<tool_use>
<tool_name>TaskOutput</tool_name>
<parameters>
  <task_id>agent_id_2</task_id>
  <block>false</block>
  <timeout>5000</timeout>
</parameters>
</tool_use>
```

**Wait until all report files exist before proceeding.**

## Error Handling

### Subagent Failure

If a subagent fails:

1. **Check the error message** in TaskOutput
2. **Log the failure** for user awareness
3. **Continue with other subagents** if possible
4. **Document which reviews** were not completed

**Example:**
```markdown
## Review Execution Status

✓ code-review:code-review - Completed
✓ security-analyzer - Completed
✗ performance-checker - Failed (timeout)
✓ style-enforcer - Completed

Note: Performance review was not completed due to timeout.
You may re-run this skill later with a smaller code scope.
```

### Retry Strategy

**For failed subagents:**
1. Analyze failure reason
2. If recoverable (timeout, resource limit):
   - Reduce scope (fewer files, smaller diff)
   - Increase timeout
   - Retry once
3. If unrecoverable (skill not found, invalid input):
   - Document and continue

## Data Sharing Between Subagents

### File System Approach

Subagents share data through the file system:

**Directory Structure:**
```
reviews/{review_name}/
├── code-context.json      # Shared by all subagents
├── diff.patch             # Shared by all subagents
└── reports/               # Each subagent writes here
    ├── skill1-report.md
    └── skill2-report.md
```

**Benefits:**
- No inter-subagent communication needed
- Independent execution
- Easy to debug and inspect
- Persistent results

### Avoiding Conflicts

**Each subagent:**
- Reads from shared input files (code-context.json, diff.patch)
- Writes to unique output file (skill-name-report.md)
- No writing to shared files
- No dependency on other subagents

## Performance Considerations

### Parallelism Limits

**Recommended parallel subagent count:** 3-5

**Too many subagents (>8):**
- Resource contention
- Diminishing returns
- Higher failure rate

**Too few subagents (<2):**
- No benefit from parallelization
- Longer total review time

### Timeout Configuration

**Set appropriate timeouts based on code size:**

| Code Size | Suggested Timeout |
|-----------|-------------------|
| Small (<500 lines) | 60,000ms (1 min) |
| Medium (500-2000 lines) | 180,000ms (3 min) |
| Large (2000-10000 lines) | 300,000ms (5 min) |
| Very Large (>10000 lines) | 600,000ms (10 min) |

**For very large codebases, consider:**
- Splitting into multiple review sessions
- Reviewing subdirectories separately
- Limiting to specific file types

## Report Consolidation

### Reading Reports

After all subagents complete:

```xml
<tool_use>
<tool_name>Read</tool_name>
<parameters>
  <file_path>/path/to/reviews/auth-feature/reports/code-review-report.md</file_path>
</parameters>
</tool_use>

<tool_use>
<tool_name>Read</tool_name>
<parameters>
  <file_path>/path/to/reviews/auth-feature/reports/security-report.md</file_path>
</parameters>
</tool_use>
```

### Parsing Reports

**Extract from each report:**
- Summary statistics (issues found, files reviewed)
- Individual issues with:
  - Severity level
  - File location
  - Line number
  - Description
  - Recommendation

**Cross-reference duplicates:**
- Group by file:line
- If multiple skills find same issue:
  - List all skills that found it
  - Consolidate into single finding
  - Note which skill found it first

## Best Practices

### 1. Launch in Single Message

**✓ Good:** Launch all subagents in one message
```xml
<!-- 3 Task calls in one message -->
```

**✗ Bad:** Launch subagents sequentially
```
Task(...wait...) Task(...wait...) Task(...)
```

### 2. Use Unique Report Paths

**✓ Good:** Each subagent gets unique path
```
reports/code-review-report.md
reports/security-report.md
reports/performance-report.md
```

**✗ Bad:** Shared report path
```
reports/report.md  # Overwrites!
```

### 3. Provide Clear Instructions

**✓ Good:** Specific task, clear output format
```
Review code in /path/to/diff.patch using security-analyzer skill.
Output report to /path/to/reports/security-report.md in markdown format.
Include severity levels (Critical, High, Medium, Low).
```

**✗ Bad:** Vague task
```
Review the code.
```

### 4. Handle Failures Gracefully

**✓ Good:** Continue with available reports
```
3/5 reviews completed. Proceeding with partial results.
```

**✗ Bad:** Abort on any failure
```
One subagent failed. Aborting entire review.
```

## Troubleshooting

### Subagent Not Starting

**Symptoms:** Task tool returns immediately without task_id

**Causes:**
- Invalid subagent_type
- Agent system not available
- Permission issues

**Solutions:**
- Verify subagent_type is valid
- Check Claude Code agent system is running
- Review error messages

### Subagent Hangs

**Symptoms:** Timeout exceeded, no output

**Causes:**
- Code too large
- Infinite loop in skill
- Resource exhaustion

**Solutions:**
- Reduce scope (fewer files)
- Increase timeout
- Check system resources

### Report Not Generated

**Symptoms:** Subagent completes but no report file

**Causes:**
- Subagent didn't follow instructions
- Output path incorrect
- Permission issues

**Solutions:**
- Verify output path exists
- Check subagent logs
- Prompt includes explicit output instruction

### Duplicate Issues

**Symptoms:** Same issue reported multiple times

**Causes:**
- Multiple skills detect same problem
- No deduplication logic

**Solutions:**
- Consolidate by file:line
- List all skills that found it
- Keep most detailed description
