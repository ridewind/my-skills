---
name: code-review-orchestrator
description: This skill should be used when the user asks to "review code", "do a code review", "review my branch", "review MR !1234", "review PR #567", "review feature/auth branch", "review feature/auth vs dev", "check code quality", "review entire project", "review all code", or wants to orchestrate multiple code review skills/subagents. Coordinates parallel code reviews using multiple review skills and generates comprehensive summary reports.
version: 0.5.0
---

# Code Review Orchestrator

Orchestrate comprehensive code reviews by coordinating multiple review skills and subagents in parallel, then consolidate findings into actionable reports.

## Purpose

This skill manages the complete code review workflow:
- Collect and organize code content for review (diffs, commits, branches, MR/PR info)
- Coordinate multiple subagents using different review skills
- Consolidate individual review reports into comprehensive summaries
- Help users identify and fix issues

## Debug Mode

**Configuration**: Debug mode can be controlled via user input or interactive confirmation.

**How to Enable Debug Mode**:
1. **Automatic**: Include debug keywords in your request (`debug`, `verbose`, `调试`, `详细`, `--debug`, `-v`)
2. **Interactive**: When prompted, select "启用调试" to enable detailed logging

**Debug Mode Records** (when enabled):
- All checkpoints and decision points
- User selections and confirmations
- Subagent launch and completion status
- Timestamps and progress tracking
- Complete interaction history

**Output**: Saved to `DEBUG-SESSION.md` in the working directory

**To force always-on**: Change Step 0 to always set `debug_mode = True`

## When to Use

Trigger this skill when users request code review with phrases like:
- "Review my code"
- "Review feature/auth branch"
- "Review MR !1234" / "Review PR #567"
- "Review feature/auth vs dev branch"
- "Do a comprehensive code review"

## Workflow

**DEBUG MODE CONFIGURATION**: Debug mode can be controlled via user input or interactive confirmation.

### Step 0: Debug Mode Detection (Optional)

**🔍 DEBUG [Step 0/7]**: Checking if debug mode should be enabled

Determine whether to enable detailed debug logging based on user input or confirmation.

**Automatic Detection**:
Check user's initial input for debug-related keywords:
- `debug`, `verbose`, `detail`, `log`, `trace`
- `--debug`, `-v`, `--verbose`
- Chinese: `调试`, `详细`, `日志`, `记录`

**Detection Logic**:
```python
# Get user's initial input
user_input = "<user's original request>"  # e.g., "Review my code with debug"
user_input_lower = user_input.lower()

# Keywords that trigger debug mode
debug_keywords = [
    'debug', 'verbose', 'detail', 'log', 'trace',
    '--debug', '-v', '--verbose',
    '调试', '详细', '日志', '记录'
]

# Auto-detect
debug_mode = any(keyword in user_input_lower for keyword in debug_keywords)

if debug_mode:
    print("✅ Debug mode automatically enabled (keyword detected)")
else:
    # Ask user if they want debug mode
    response = AskUserQuestion(
        questions=[
            {
                "question": "是否启用详细调试日志？\n\n启用后会记录完整的审查过程，包括：\n- 所有决策点和选择\n- 子代理启动和完成状态\n- 时间戳和进度信息\n- 完整的交互历史\n\n生成的日志将保存到 DEBUG-SESSION.md 文件中。",
                "header": "调试模式",
                "options": [
                    {
                        "label": "启用调试",
                        "description": "记录完整审查过程到DEBUG-SESSION.md"
                    },
                    {
                        "label": "不启用",
                        "description": "仅显示基本进度信息，不生成详细日志"
                    }
                ],
                "multiSelect": False
            }
        ]
    )
    debug_mode = (response == "启用调试")
```

**Debug Mode Behavior**:
- **Enabled**: Record all 🔍 checkpoints, user choices, timestamps, subagent status to DEBUG-SESSION.md
- **Disabled**: Only show basic progress indicators, no detailed session log

**🔍 DEBUG Status**: `Debug mode = {debug_mode}`

---

### Step 1: Determine Review Scope

**🔍 DEBUG [Step 1/7]**: Starting - Determine Review Scope

Identify what code to review based on user input:

**Review Sources:**
- **Branch**: Single branch (e.g., `feature/auth`) - review all changes in branch
- **Branch Comparison**: Branch A vs Branch B (e.g., `feature/auth` vs `dev`) - **IMPORTANT**: Find merge base and diff from merge base to branch A's HEAD
- **MR/PR**: Merge Request (GitLab) or Pull Request (GitHub) by number or URL
- **Project**: Monorepo with multiple subprojects - ask which to review
- **Full Project**: Multiple independent projects or entire codebase - collect all project paths

**Required Information:**
- Branch names (if comparing branches)
- MR/PR number or URL
- Project paths (for monorepos or full project review)
- Repository URL (if not current directory)

**For Full Project Review:**
When user asks to "review entire project" or "review all code":
1. Ask user to specify which projects/directories to review
2. For each project, check if it's a git repository
3. Collect project metadata (tech stack, LOC, file count)
4. Confirm with user before proceeding

### Step 2: Establish Working Directory

**🔍 DEBUG [Step 2/7]**: Establishing working directory

**IMPORTANT**: Working directory name MUST include date and sequence number to avoid conflicts.

**Directory Naming Convention**: `{review_name}-{YYYYMMDD}-{sequence}`

**Generate unique working directory**:
```bash
# Get current date
DATE=$(date +%Y%m%d)

# Base directory name
BASE_DIR="{review_name}-${DATE}"

# Find existing directories with same base
EXISTING=$(ls -d reviews/${BASE_DIR}-* 2>/dev/null | wc -l)

# Calculate next sequence number
SEQUENCE=$((EXISTING + 1))

# Final directory name
WORKING_DIR="${BASE_DIR}-${SEQUENCE}"
```

**Examples**:
```
First review on 2026-01-30:    mr557-aihub-refactor-20260130-1
Second review on same day:     mr557-aihub-refactor-20260130-2
First review next day:         mr557-aihub-refactor-20260131-1
```

**Full path**: `{project_root}/reviews/{review_name}-{YYYYMMDD}-{sequence}`

**Implementation**:
```bash
# Example implementation
project_root="/home/user/myapp"
review_name="auth-feature"
date=$(date +%Y%m%d)

# Check for existing reviews today
existing_dirs=$(find "$project_root/reviews" -maxdepth 1 -name "${review_name}-${date}-*" | wc -l)
sequence=$((existing_dirs + 1))

working_dir="$project_root/reviews/${review_name}-${date}-${sequence}"
mkdir -p "$working_dir"
```

**Ask user for confirmation with generated directory name** (optional, can be auto-generated)

**Directory Structure:**
```
reviews/{review_name}-{YYYYMMDD}-{sequence}/
├── code-context.json                     # All review metadata
├── diff.patch                             # Git diff output
├── commits.json                           # Commit history
├── branch-info.json                       # Branch details
├── DEBUG-SESSION.md                       # Debug session log (always uppercase)
├── {review_name}-{YYYYMMDD}-{sequence}-comprehensive-summary.md # Final report
└── reports/                               # Individual skill reports
    ├── skill1-report.md
    ├── skill2-report.md
    └── ...
```

**IMPORTANT File Naming Conventions:**
1. **Working directory**: `{review_name}-{YYYYMMDD}-{sequence}` (date + sequence for uniqueness)
2. **Summary file**: `{review_name}-{YYYYMMDD}-{sequence}-comprehensive-summary.md` (include date+sequence)
3. **Debug session file**: `DEBUG-SESSION.md` (always uppercase, fixed name)
4. **Individual reports**: `{skill-name}-report.md` (use skill's short name)
5. **Context files**: lowercase with hyphens (code-context.json, diff.patch, etc.)

### Step 3: Collect and Save Code Content

**🔍 DEBUG [Step 3/7]**: Collecting code context and metadata

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
  "working_directory": "/path/to/reviews/auth-feature-20260130-1",
  "review_date": "2026-01-30",
  "review_sequence": 1,
  "timestamp": "2026-01-30T14:30:22Z"
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

**For Full Project Review (non-Git or multi-project):**
```json
{
  "review_type": "full_project",
  "review_name": "full-project-review",
  "working_directory": "/path/to/reviews/full-project-review-20260130-1",
  "review_date": "2026-01-30",
  "review_sequence": 1,
  "projects": [
    {
      "name": "frontend",
      "path": "/path/to/frontend",
      "tech_stack": ["Nuxt.js", "Vue 2"],
      "language": "javascript"
    },
    {
      "name": "backend",
      "path": "/path/to/backend",
      "tech_stack": ["Spring Boot", "MyBatis"],
      "language": "java"
    }
  ]
}
```

**Critical for Branch Comparison:**
When comparing branch A vs branch B:
1. Find merge base: `git merge-base A B`
2. Diff from merge base to A: `git diff merge_base...A`
3. This ensures only unique changes in A are reviewed

**Confirm with User:**
After collecting code context, present to user using AskUserQuestion tool:

**🔍 DEBUG [Checkpoint 1]**: Display collected information and request confirmation

**IMPORTANT**: Use AskUserQuestion tool for user confirmation, not text prompts.

**Example AskUserQuestion call:**
```python
AskUserQuestion(
    questions=[
        {
            "question": "代码审查信息已收集，是否继续？",
            "header": "确认审查",
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
            "multiSelect": false
        }
    ]
)
```

**Information to present in question description:**
```
Review Type: Full project review
Projects: 2 projects (frontend, backend)

Frontend:
  - Path: /projects/bupt/eduiot-lab
  - LOC: ~13,800
  - Tech Stack: Nuxt.js, Vue 2, Element UI

Backend:
  - Path: /projects/bupt/space-server
  - LOC: ~7,000
  - Tech Stack: Spring Boot, MyBatis, MySQL

Working Directory: /projects/bupt/reviews/full-project-review-20260130-1
```

**🔍 DEBUG**: Wait for user confirmation via AskUserQuestion before proceeding

**DO NOT proceed to Step 4 without user confirmation.**

### Step 4: Discover Available Review Skills (Multi-Round Selection)

**🔍 DEBUG [Step 4/7]**: Discovering available review skills with multi-round selection

**🔍 DEBUG**: Check system-reminder for available skills list

Identify which code review skills are available in the current environment.

**Check available skills:**
Look for skills with these patterns in their description:
- "code review", "review code", "review MR/PR"
- "security", "performance", "quality", "lint"

**Skill Category Mapping**:
Skills are organized into 4 functional categories:

```python
SKILL_CATEGORIES = {
    "代码质量": [
        "code-review:code-review",
        "comprehensive-review:code-reviewer",
        "code-review-ai:code-review",
        "codebase-cleanup:code-reviewer",
        "feature-dev:code-reviewer",
        "code-documentation:code-reviewer"
    ],
    "安全审计": [
        "security-scanning:security-auditor",
        "comprehensive-review:security-auditor",
        "security-scanning:threat-modeling-expert"
    ],
    "性能+架构": [
        "comprehensive-review:architect-review",
        "application-performance:performance-engineer",
        "backend-development:backend-architect",
        "application-performance:observability-engineer"
    ],
    "测试+清理": [
        "pr-review-toolkit:pr-test-analyzer",
        "unit-testing:test-automator",
        "pr-review-toolkit:code-simplifier",
        "pr-review-toolkit:comment-analyzer",
        "pr-review-toolkit:type-design-analyzer"
    ]
}
```

**Skill Discovery Process:**
1. Review the list of available skills in system-reminder
2. Organize skills into the 4 categories above
3. Present findings to user in DEBUG output

---

### Step 4.1: Display All Skills in DEBUG Output

**🔍 DEBUG [Checkpoint 2.1]**: Display all discovered skills by category

**CRITICAL**: Always display ALL discovered skills in DEBUG output before selection.

**Example DEBUG output:**
```python
print("🔍 发现可用的审查技能\n")
print("=" * 70)

print("\n**代码质量** (6个技能):")
for skill in SKILL_CATEGORIES["代码质量"]:
    print(f"  • {skill}")

print("\n**安全审计** (3个技能):")
for skill in SKILL_CATEGORIES["安全审计"]:
    print(f"  • {skill}")

print("\n**性能+架构** (4个技能):")
for skill in SKILL_CATEGORIES["性能+架构"]:
    print(f"  • {skill}")

print("\n**测试+清理** (5个技能):")
for skill in SKILL_CATEGORIES["测试+清理"]:
    print(f"  • {skill}")

print("=" * 70)
print(f"🔍 共发现 {sum(len(v) for v in SKILL_CATEGORIES.values())} 个审查技能\n")
```

---

### Step 4.2: Round 1 - Select Review Categories

**🔍 DEBUG [Checkpoint 2.2]**: First round selection - choose categories

**IMPORTANT**: Use AskUserQuestion tool for category selection.

**AskUserQuestion call:**
```python
AskUserQuestion(
    questions=[
        {
            "question": f"""
请选择审查类别（可多选）:

**代码质量** (6个技能): 代码规范、潜在bug、可维护性、架构分析、代码清理
**安全审计** (3个技能): 安全漏洞、OWASP Top 10、威胁建模
**性能+架构** (4个技能): 性能优化、架构审查、设计模式、后端架构
**测试+清理** (5个技能): 测试覆盖、代码清理、代码简化、注释分析

**待审查项目**:
- 前端: Nuxt.js + Vue 2 (~118 文件)
- 后端: Spring Boot + Java 21 (~107 Java文件)

**提示**: 选择多个类别可以进行更全面的审查
""",
            "header": "审查类别",
            "options": [
                {
                    "label": "代码质量",
                    "description": "包含 code-review, comprehensive-reviewer, code-review-ai, codebase-cleanup, feature-dev, code-documentation"
                },
                {
                    "label": "安全审计",
                    "description": "包含 security-auditor, comprehensive-security, threat-modeling-expert"
                },
                {
                    "label": "性能+架构",
                    "description": "包含 architect-review, performance-engineer, backend-architect, observability-engineer"
                },
                {
                    "label": "测试+清理",
                    "description": "包含 pr-test-analyzer, test-automator, code-simplifier, comment-analyzer, type-design-analyzer"
                }
            ],
            "multiSelect": True
        }
    ]
)
```

**🔍 DEBUG**: Show user's category selection: `["代码质量", "安全审计"]`

---

### Step 4.3: Round 2 - Select Specific Skills

**🔍 DEBUG [Checkpoint 2.3]**: Second round selection - choose specific skills

For each category selected in Round 1, present specific skills.

**Example: User selected "代码质量" category**

```python
AskUserQuestion(
    questions=[
        {
            "question": """
请选择**代码质量**类别的具体技能（可多选）:

**通用审查**: code-review:code-review - 代码规范、bug、可维护性
**深度分析**: comprehensive-review:code-reviewer - 架构、设计模式
**AI驱动**: code-review-ai:code-review - AI增强的代码审查
**代码清理**: codebase-cleanup:code-reviewer - 优化、简化
**功能开发**: feature-dev:code-reviewer - 功能开发审查
**文档审查**: code-documentation:code-reviewer - 精英代码审查
""",
            "header": "代码质量技能",
            "options": [
                {
                    "label": "code-review:code-review",
                    "description": "通用代码质量 - 代码规范、bug、可维护性"
                },
                {
                    "label": "comprehensive-review:code-reviewer",
                    "description": "深度代码分析 - 架构、设计模式"
                },
                {
                    "label": "codebase-cleanup:code-reviewer",
                    "description": "代码清理 - 优化、简化"
                },
                {
                    "label": "使用全部代码质量技能",
                    "description": "使用该类别下的所有6个技能"
                }
            ],
            "multiSelect": True
        }
    ]
)
```

**Example: User selected "安全审计" category**

```python
AskUserQuestion(
    questions=[
        {
            "question": """
请选择**安全审计**类别的具体技能（可多选）:

**安全漏洞**: security-scanning:security-auditor - OWASP Top 10、注入攻击
**综合安全**: comprehensive-review:security-auditor - 全面安全分析
**威胁建模**: security-scanning:threat-modeling-expert - 安全架构分析
""",
            "header": "安全审计技能",
            "options": [
                {
                    "label": "security-scanning:security-auditor",
                    "description": "安全漏洞 - OWASP Top 10、注入攻击"
                },
                {
                    "label": "comprehensive-review:security-auditor",
                    "description": "综合安全审计 - 全面安全分析"
                },
                {
                    "label": "security-scanning:threat-modeling-expert",
                    "description": "威胁建模 - 安全架构分析"
                },
                {
                    "label": "使用全部安全审计技能",
                    "description": "使用该类别下的所有3个技能"
                }
            ],
            "multiSelect": True
        }
    ]
)
```

**CRITICAL Rules for Skill Selection:**
1. **Multi-round selection**: First select categories, then select specific skills
2. **Always display ALL skills in DEBUG output** before selection
3. **AskUserQuestion label MUST be exact skill name** (e.g., "code-review:code-review")
4. **Use multiSelect: True** for both rounds
5. **Offer "使用全部[类别]技能" option** for convenience
6. **Include project details** to help user choose appropriate skills

**🔍 DEBUG**: Show final skill selection: `["code-review:code-review", "security-scanning:security-auditor", ...]`

**Ask user to select which skills to use using AskUserQuestion.**
**DO NOT proceed to Step 5 without user skill selection.**

### Step 5: Launch Parallel Subagents

**🔍 DEBUG [Step 5/7]**: Launching parallel subagents with review skills

**🔍 DEBUG**: Show selected skills and subagent configuration before launch

**Use Task tool with run_in_background=true** to launch multiple subagents in parallel.

**CRITICAL**: Each subagent MUST use a DIFFERENT review skill via the Skill tool.

**Example parallel launch:**

**🔍 DEBUG [Checkpoint 3]**: Display subagent launch configuration

```
═════════════════════════════════════════════════════════
🚀 Launching Parallel Subagents
═════════════════════════════════════════════════════════

Subagent 1: code-review:code-review
  - Review scope: Frontend (Nuxt.js)
  - Output: reports/code-review-report.md

Subagent 2: security-scanning:security-auditor
  - Review scope: Both projects
  - Output: reports/security-report.md

Subagent 3: pr-review-toolkit:review-pr
  - Review scope: All files
  - Output: reports/pr-review-report.md
═════════════════════════════════════════════════════════
```

**🔍 DEBUG**: Track subagent status
```
Agent 1 (code-review): ⏳ Starting...
Agent 2 (security):    ⏳ Starting...
Agent 3 (pr-review):    ⏳ Starting...
```

**Provide each subagent with:**
- Location of `code-context.json`
- Location of `diff.patch` (for git reviews) OR project paths (for full project review)
- Output report path: `reports/{skill-name}-report.md`
- **INSTRUCTION to use Skill tool to invoke the review skill**

**Subagent Prompt Template:**
```markdown
You are reviewing code as part of a comprehensive code review.

**Your assigned skill**: {skill_name}

**Task**:
1. Use the Skill tool to invoke: {skill_name}
2. Provide the skill with:
   - Review scope: {scope_description}
   - Code location: {code_path}
   - Any additional context from code-context.json
3. Generate a comprehensive report following that skill's workflow
4. Save your report to: {output_path}

**IMPORTANT**:
- You MUST use the Skill tool to invoke {skill_name}
- Do NOT review code manually - let the skill guide you
- The skill will provide the specific review methodology
- Follow the skill's workflow exactly
```

**Example Task tool calls:**
```yaml
Task 1:
  subagent_type: general-purpose
  description: Review using code-review:code-review
  run_in_background: true
  prompt: |
    You are reviewing the frontend code using the code-review:code-review skill.
    Project path: /projects/bupt/eduiot-lab
    Output: /projects/bupt/reviews/full-project-review/reports/code-review-report.md
    Use the Skill tool to invoke code-review:code-review

Task 2:
  subagent_type: general-purpose
  description: Review using security-scanning:security-auditor
  run_in_background: true
  prompt: |
    You are reviewing both frontend and backend for security issues.
    Frontend: /projects/bupt/eduiot-lab
    Backend: /projects/bupt/space-server
    Output: /projects/bupt/reviews/full-project-review/reports/security-report.md
    Use the Skill tool to invoke security-scanning:security-auditor

Task 3:
  subagent_type: general-purpose
  description: Review using pr-review-toolkit:review-pr
  run_in_background: true
  prompt: |
    You are reviewing code quality using pr-review-toolkit:review-pr skill.
    Review all files in both projects.
    Output: /projects/bupt/reviews/full-project-review/reports/pr-review-report.md
    Use the Skill tool to invoke pr-review-toolkit:review-pr
```

**File Writing Strategy:**
- Subagents should use Write tool to save their reports
- If subagents cannot write files, they should output the full report content
- Main agent: Collect all outputs and save using Write tool
- Ensure `reports/` directory exists before launching subagents

**Wait for all subagents to complete** using TaskOutput tool before proceeding to Step 6.

**🔍 DEBUG**: Show subagent completion status
```
Agent 1 (code-review): ✅ Complete
Agent 2 (security):    ✅ Complete
Agent 3 (pr-review):    ✅ Complete

All reports generated successfully!
```

### Step 6: Generate Consolidated Summary

**🔍 DEBUG [Step 6/7]**: Generating consolidated summary from all reports

**🔍 DEBUG [Checkpoint 4]**: Display report collection status

```
═════════════════════════════════════════════════════════
📊 Collecting Reports from Subagents
═════════════════════════════════════════════════════════

Found 3 reports in reports/ directory:
✓ code-review-report.md (32 issues found)
✓ security-report.md (19 issues found)
✓ pr-review-report.md (25 issues found)

Total issues to consolidate: 76 issues
═════════════════════════════════════════════════════════
```

**🔍 DEBUG**: Show categorization progress
```
Categorizing issues by severity...
- Critical: 3 issues
- High: 13 issues
- Medium: 31 issues
- Low: 29 issues
```

**Read all individual reports** from `reports/` directory.

**Analyze findings and categorize by severity:**
- **Critical**: Security vulnerabilities, crashes, data loss risks
- **High**: Major bugs, performance issues, breaking changes
- **Medium**: Code smells, maintainability issues
- **Low**: Style issues, minor optimizations

**Create `{review_name}-{YYYYMMDD}-{sequence}-comprehensive-summary.md`:**

**IMPORTANT File Naming Convention:**
- **Summary file**: `{review_name}-{YYYYMMDD}-{sequence}-comprehensive-summary.md` (include date+sequence)
- **Debug session file**: `DEBUG-SESSION.md` (always uppercase, fixed name)

**Structure:**
```markdown
# Code Review Comprehensive Summary: {review_name}

## 🤖 Review Skills Used

This review used multiple AI skills, each analyzing from different perspectives:

| Skill Name | Focus Area | Key Contributions |
|------------|------------|-------------------|
| code-review:code-review | 代码质量与最佳实践 | 代码规范、潜在bug、可维护性 |
| security-scanning:security-auditor | 安全漏洞审计 | OWASP Top 10、注入攻击、认证授权 |
| pr-review-toolkit:review-pr | 全面PR审查 | 功能完整性、测试覆盖、文档 |

**Total Issues Found**: X issues (after deduplication)

## Overview
- Review Type: Branch comparison (feature/auth vs dev)
- Commits: 5 commits
- Files changed: 12 files
- Review Skills: 3 skills used in parallel
- Date: 2025-01-28

## Findings Summary
- Critical: 2 issues
- High: 5 issues
- Medium: 8 issues
- Low: 3 issues

## 🔴 Critical Issues

### 1. SQL Injection Risk in auth/login.js
- **Location**: `src/auth/login.js:45`
- **Severity**: Critical
- **Found by**: code-review:code-review, security-scanning:security-auditor
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

### 2. Authentication Bypass
- **Location**: `src/auth/check.js:12`
- **Severity**: Critical
- **Found by**: security-scanning:security-auditor, pr-review-toolkit:review-pr
- **Issue**: Missing authentication check on admin endpoint
- **Recommendation**: Add authentication middleware

## 🟠 High Priority Issues

### 1. Missing Error Handling in API client
- **Location**: `src/api/client.js:78`
- **Severity**: High
- **Found by**: code-review:code-review
- **Issue**: No try-catch around fetch request
- **Recommendation**: Add error handling with retry logic

## 🟡 Medium Priority Issues

### 1. Inconsistent Naming Convention
- **Location**: Multiple files
- **Severity**: Medium
- **Found by**: code-review:code-review
- **Issue**: Mix of camelCase and snake_case
- **Recommendation**: Standardize on camelCase

## 🟢 Low Priority Issues

### 1. Unused Imports
- **Location**: `src/utils/helpers.js:3`
- **Severity**: Low
- **Found by**: code-review:code-review
- **Issue**: Import 'lodash' unused
- **Recommendation**: Remove unused imports

**CRITICAL TEMPLATE RULES**:
1. **EVERY issue MUST include "Found by" field**
2. Use **complete skill names** (e.g., "code-review:code-review, security-scanning:security-auditor")
3. Use **comma separation** for multiple skills
4. **DO NOT use abbreviations** or symbols (not "[CR]", "[SA]", etc.)
5. If unsure which skill found it, check the individual skill reports
6. If multiple skills found same issue, list ALL of them in "Found by"

## 📊 Skill Contributions Summary

### code-review:code-review
**Issues Found**: X
**Focus**: 代码质量与最佳实践
**Key Findings**:
- Finding 1
- Finding 2

### security-scanning:security-auditor
**Issues Found**: Y
**Focus**: 安全漏洞审计
**Key Findings**:
- Finding 1
- Finding 2

### pr-review-toolkit:review-pr
**Issues Found**: Z
**Focus**: 全面PR审查
**Key Findings**:
- Finding 1
- Finding 2

## Detailed Reports

Individual skill reports:
- [code-review:code-review report](reports/code-review-report.md)
- [security-scanning:security-auditor report](reports/security-auditor-report.md)
- [pr-review-toolkit:review-pr report](reports/pr-review-report.md)
```

### Step 7: Generate Debug Session Log (If Debug Mode Enabled)

**🔍 DEBUG [Step 7/7]**: Generating DEBUG-SESSION.md

**CRITICAL**: Only execute this step if `debug_mode = True` from Step 0.

**When to Generate**: After comprehensive summary is complete, before interactive issue resolution.

**What to Record**:
```markdown
# Code Review Orchestrator - Session Debug Log

**Session Date**: {CURRENT_DATE}
**Session ID**: {review_name}-{YYYYMMDD}-{sequence}
**Working Directory**: `{full_path_to_working_dir}`
**Skill**: code-review-orchestrator
**Status**: ✅ COMPLETED

---

## 1. Session Configuration

### User Input
- **原始请求**: "{user's original request}"
- **意图**: {review_type}
- **项目数量**: {number_of_projects}

### Identified Projects
**Project 1 ({name})**:
- Path: `{path}`
- Tech Stack: {tech_stack}
- File Count: {count}
- Language: {language}

### Working Directory Creation
```bash
DATE={date}
EXISTING_COUNT={existing_count}
SEQUENCE={sequence}
WORKING_DIR="{working_dir}"
# Result: {final_working_dir}
```

---

## 2. Execution Timeline

### Step 0: Debug Mode Detection
**Time**: {start_time} - {end_time}
- ✅ Debug mode: {ENABLED/DISABLED}
- Detection method: {keyword_detected / user_confirmed}

### Step 1: Determine Review Scope
**Time**: {start_time} - {end_time}
- ✅ Identified as: {review_type}
- ✅ Discovered {number} projects
- ✅ Collected project metadata

### Step 2: Establish Working Directory
**Time**: {start_time}
- ✅ Created unique directory with date and sequence
- ✅ Created reports/ subdirectory
- ✅ Confirmed directory structure

### Step 3: Collect Code Context
**Time**: {start_time} - {end_time}
- ✅ Saved code-context.json
- **Content**: Project metadata, tech stack, file counts

### Step 4: User Confirmation
**Time**: {time}
- ✅ Used AskUserQuestion tool
- **User Choice**: "{choice}"
- Confirmation received

### Step 5: Skill Selection
**Time**: {start_time} - {end_time}
- ✅ Discovered available skills
- ✅ Presented skill options to user
- **User Choice**: "{choice}"

**Selected Skills**:
1. {skill_name_1}
2. {skill_name_2}
3. {skill_name_3}
...

### Step 6: Launch Subagents
**Time**: {start_time} - {end_time}

**Subagent 1**:
- Agent ID: {agent_id}
- Task: {task_description}
- Status: ✅ Completed
- Output: {output_path}
- Report: {report_path}

**Subagent 2**:
- Agent ID: {agent_id}
- Task: {task_description}
- Status: ✅ Completed
- Output: {output_path}
- Report: {report_path}

...

### Step 7: Generate Comprehensive Summary
**Time**: {start_time} - {end_time}
- ✅ Read all generated reports
- ✅ Consolidated findings
- ✅ Created comprehensive summary
- ✅ Saved: {summary_file_name}

**Total Duration**: ~{total_time}

---

## 3. Files Generated

### Primary Output Files
```
{working_directory}/
├── code-context.json                              # Review metadata
├── {review_name}-{YYYYMMDD}-{sequence}-comprehensive-summary.md  # Main report
└── reports/
    ├── skill1-report.md                           # {size}, {lines} lines
    ├── skill2-report.md                           # {size}, {lines} lines
    └── ...
```

---

## 4. Key Decisions and Rationale

### Decision 1: Review Type Determination
**Input**: "{user_input}"
**Analysis**: {analysis}
**Decision**: {decision}
**Rationale**: {rationale}

### Decision 2: Skill Selection Strategy
**Options Presented**: {options}
**User Choice**: "{user_choice}"
**Selected Skills**: {skills_list}
**Rationale**: {rationale}

---

## 5. Issues Encountered

### Issue 1: {issue_title}
**Problem**: {problem_description}
**Resolution**: {resolution}
**Impact**: {impact}

---

## 6. Performance Metrics

### Execution Time
- Total Duration: ~{total_time}
- Per Subagent Average: ~{average_time}
- Consolidation: ~{consolidation_time}

### Resource Usage
- Subagents: {number} parallel agents
- Tokens Used: Estimated {token_count}+ tokens
- Files Generated: {number} files (~{total_lines} lines total)

### Success Rate
- Subagents Completed: {completed}/{total} ({percentage}%)
- Reports Saved: {saved}/{total} ({percentage}%)
- Findings Integrated: {integrated}/{total} ({percentage}%)

---

## 7. Findings Summary

### By Dimension
**Code Quality**: {grade}
**Security**: {grade}
**Architecture**: {grade}
**Test Coverage**: {grade}

---

## 8. Recommendations for Improvement

### Process Improvements
1. {improvement_1}
2. {improvement_2}
3. {improvement_3}

---

## 9. Session Context

### Initial Request
```
User: {user_command}
Arguments: {user_arguments}
```

### Execution Flow
1. {step_1}
2. {step_2}
3. {step_3}
...

---

## 10. Technical Details

### Environment
- **Platform**: {platform}
- **OS**: {os_version}
- **Date**: {date}
- **Working Directory**: {working_dir}
- **Git Repository**: {git_status}

### Tool Versions
- **Claude Code**: {version}
- **Skill Version**: code-review-orchestrator v{version}
- **Subagents**: {agent_type} ({number} instances)

---

## 11. Error Log

### Errors Encountered
{if_errors_exist}
### Error 1: {error_title}
```
{error_details}
```
**Resolution**: {resolution}
{else}
No errors encountered during this session.
{end_if}

---

**END OF SESSION DEBUG LOG**

Generated: {generation_time}
Logger: Claude Code (code-review-orchestrator skill v{version})
Session: {session_id}
```

**Save Location**: `{working_directory}/DEBUG-SESSION.md`

**🔍 DEBUG**: Session log saved to DEBUG-SESSION.md

---

### Step 8: Interactive Issue Resolution

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

### Full Project Review

When reviewing entire projects or multiple independent projects:

**1. Discover Project Structure**
- Use `ls` and `find` to understand directory layout
- Check for package.json, pom.xml, requirements.txt, etc.
- Identify tech stack and language
- Count lines of code

**2. Collect Project Metadata**
```bash
# Example: Frontend project
cd /projects/bupt/eduiot-lab
find . -name "*.vue" -o -name "*.js" | wc -l  # Count files
cat package.json  # Identify framework

# Example: Backend project
cd /projects/bupt/space-server
find . -name "*.java" | wc -l  # Count files
cat pom.xml  # Identify framework
```

**3. Use Appropriate Review Skills**
- For frontend: code-review:code-review, javascript-typescript:javascript-pro
- For backend: code-review:code-review, jvm-languages:java-pro
- For security: security-scanning:security-auditor
- For architecture: code-review-ai:architect-review

**4. Coordinate Subagent Communication**
- Each subagent reviews independently
- No inter-subagent communication needed
- Main agent consolidates all reports
- Use file system for data sharing

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

### Project Not Recognized

**Problem**: Commands like `cd space-server` fail with "No such file or directory"

**Root Cause**: Skill assumes git workflow, but user has independent projects

**Solutions:**
1. Identify this is "full project review", not branch comparison
2. Use absolute paths to projects
3. Don't use `cd` - use full paths in commands
4. Ask user to confirm project paths

**Example:**
```bash
# WRONG
cd space-server && git log

# RIGHT
cd /projects/bupt/space-server && git log
# OR
git -C /projects/bupt/space-server log
```

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

### Subagents Cannot Write Files

**Problem**: Report files not created in `reports/` directory

**Root Cause**: Subagents may not have write permissions or Write tool access

**Solutions:**
1. Main agent creates `reports/` directory before launching subagents
2. Subagent attempts to write file using Write tool
3. If write fails, subagent outputs full report content as text
4. Main agent collects outputs and saves using Write tool

**Pattern:**
```yaml
# Main agent
mkdir -p reports/

# Launch subagent with fallback instruction
Task(prompt: |
  1. Perform review using {skill}
  2. Try to save report to: reports/{skill}-report.md
  3. If Write tool fails, output full report as markdown text
  4. Include "REPORT_START" and "REPORT_END" markers
)

# Main agent collects output
TaskOutput(task_id, block=true)
Read output file, extract report between markers
Save using Write tool
```

### Skills Not Discovered

**Problem**: No review skills found or presented to user

**Solutions:**
- Check system-reminder for available skills list
- Look for skills with "review" in description
- Ask user which skills they want to use
- Fall back to general-purpose agents with custom prompts

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
