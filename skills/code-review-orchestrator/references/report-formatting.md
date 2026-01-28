# Report Formatting Standards

Standards for formatting individual skill reports and consolidated summary reports.

## Individual Skill Report Format

Each subagent should output a markdown report with consistent structure.

### Required Sections

**1. Header**
```markdown
# Code Review Report: {Skill Name}

**Review Type**: {Branch Comparison | MR Review | PR Review | Branch Review}
**Date**: {ISO 8601 timestamp}
**Reviewer**: {Skill Name}
**Code Location**: {project/path}
**Diff Size**: {lines added, lines removed, files changed}
```

**2. Summary Statistics**
```markdown
## Summary

- **Files Reviewed**: {count}
- **Issues Found**: {count}
  - Critical: {count}
  - High: {count}
  - Medium: {count}
  - Low: {count}
- **Review Duration**: {time}
```

**3. Issues by Severity**

```markdown
## Critical Issues

### Issue Title
- **Location**: `file:path:line`
- **Severity**: Critical
- **Category**: {Security | Performance | Correctness | Style}
- **Description**: Clear explanation of the issue

**Current Code:**
```language
// Code snippet showing the problem
```

**Recommended Fix:**
```language
// Code snippet showing the fix
```

**Impact**: {Why this matters}
**Priority**: {Fix immediately / Fix before merge / Fix soon}

---

## High Priority Issues

[Same structure as Critical Issues]

## Medium Priority Issues

[Same structure as Critical Issues]

## Low Priority Issues

[Same structure as Critical Issues]
```

**4. Positive Findings (Optional)**
```markdown
## Good Practices Found

List positive patterns, good code quality, well-designed solutions.

### Well-Structured Error Handling
The error handling in `src/api/client.js` follows best practices with...
```

**5. Skill-Specific Metrics (Optional)**
```markdown
## Additional Metrics

{Skill-specific metrics, e.g.}

- Cyclomatic Complexity: {average}
- Code Duplication: {percentage}
- Test Coverage: {percentage}
- Security Score: {score}
```

### Issue Template

**Use this template for each issue:**

```markdown
### {Descriptive Title}

- **Location**: `path/to/file.ext:line_number`
- **Severity**: {Critical | High | Medium | Low}
- **Category**: {Security | Performance | Correctness | Maintainability | Style | Documentation}
- **Rule/Pattern**: {Relevant rule or pattern name, if applicable}

**Description:**
{Clear, concise explanation of the issue. Why is it a problem?}

**Current Code:**
```language
// Include 3-10 lines surrounding the issue
function vulnerable() {
  const query = `SELECT * FROM users WHERE id = ${input}`;
  return db.execute(query);
}
```

**Recommended Fix:**
```language
// Show the corrected code
function secure() {
  const query = 'SELECT * FROM users WHERE id = ?';
  return db.execute(query, [input]);
}
```

**Impact:**
{What happens if this is not fixed? Security risk? Performance degradation? Maintenance burden?}

**Priority:**
{When should this be fixed?}

**References:**
{Links to relevant documentation, CWE, best practices, etc.}
```

## Consolidated Summary Report Format

The orchestrator generates a summary report combining all individual reports.

### Report Structure

```markdown
# Code Review Summary: {Review Name}

**Review Date**: {ISO 8601 timestamp}
**Review Type**: {Branch Comparison | MR/PR Review}
**Branches**: {source_branch} vs {target_branch}
**Repository**: {repo_url}
**Reviewer Skills**: {list of skills used}

## Executive Summary

{Brief overview of the review results}

- **Total Issues**: {count}
- **Critical Issues**: {count} ⚠️
- **High Priority**: {count} ⚡
- **Medium Priority**: {count} 📝
- **Low Priority**: {count} 💡

**Recommendation**: {
  - ✅ Approve - No issues found
  - ⚠️ Approve with changes - Address critical/high issues first
  - ❌ Request changes - Critical issues must be fixed
}

## Critical Issues ⚠️

{All critical issues from all reports, consolidated}

### {Issue Title}
- **Location**: `file:line`
- **Found by**: {skill names}
- **Severity**: Critical

[Issue details from most detailed report]

---

## High Priority Issues ⚡

{All high priority issues from all reports, consolidated}

### {Issue Title}
- **Location**: `file:line`
- **Found by**: {skill names}
- **Severity**: High

[Issue details]

---

## Medium Priority Issues 📝

{Medium priority issues, optionally summarized if many}

## Low Priority Issues 💡

{Low priority issues, optionally grouped by category}

## Statistics

### Issues by Category

| Category | Critical | High | Medium | Low | Total |
|----------|----------|------|--------|-----|-------|
| Security | 2 | 3 | 1 | 0 | 6 |
| Performance | 0 | 2 | 5 | 3 | 10 |
| Correctness | 1 | 0 | 2 | 1 | 4 |
| Style | 0 | 0 | 8 | 12 | 20 |
| **Total** | **3** | **5** | **16** | **16** | **40** |

### Issues by File

| File | Critical | High | Medium | Low | Total |
|------|----------|------|--------|-----|-------|
| `src/auth/login.js` | 2 | 1 | 0 | 0 | 3 |
| `src/api/user.js` | 0 | 2 | 3 | 1 | 6 |
| `src/utils/format.js` | 0 | 0 | 1 | 5 | 6 |

### Issues by Reviewer

| Reviewer Skill | Issues Found | Critical | High |
|----------------|--------------|----------|------|
| security-analyzer | 12 | 2 | 3 |
| code-review:code-review | 15 | 1 | 2 |
| performance-checker | 8 | 0 | 0 |
| **Total (unique)** | **35** | **3** | **5** |

## Detailed Reports

Full reports from each reviewer:

- [Security Analyzer Report](reports/security-analyzer-report.md)
- [Code Review Report](reports/code-review-report.md)
- [Performance Checker Report](reports/performance-checker-report.md)

## Next Steps

### Immediate Actions Required

1. [ ] Fix SQL injection in `src/auth/login.js:45` (Critical)
2. [ ] Add error handling in `src/api/client.js:78` (High)
3. [ ] Update deprecated API usage in `src/utils/helpers.js:12` (High)

### Recommended Actions

1. Address all Critical issues before merge
2. Review High priority issues for business impact
3. Consider Medium priority issues for technical debt backlog
4. Address Low priority issues in future cleanup

### Issue Resolution Checklist

Use this checklist to track fixes:

- [ ] Critical Issue #1: SQL Injection (src/auth/login.js:45)
- [ ] Critical Issue #2: Missing Authentication (src/api/admin.js:23)
- [ ] High Issue #1: Error Handling (src/api/client.js:78)
- [ ] High Issue #2: Performance Issue (src/utils/parser.js:56)
...

## Appendix

### Code Changes Summary

**Files Changed**: {count}
**Lines Added**: {count}
**Lines Removed**: {count}
**Commits**: {count}

**Most Changed Files**:
1. `src/auth/login.js` (+150, -20 lines)
2. `src/api/user.js` (+80, -10 lines)

### Review Metadata

```json
{
  "review_type": "branch_comparison",
  "source_branch": "feature/auth",
  "target_branch": "dev",
  "merge_base": "abc123",
  "commits_analyzed": 5,
  "skills_used": [
    "security-analyzer",
    "code-review:code-review",
    "performance-checker"
  ],
  "review_duration_minutes": 15
}
```
```

## Markdown Formatting Guidelines

### Code Blocks

**Always specify language:**
````markdown
```javascript
// Good - language specified
function example() {}
```
````

````markdown
```
// Bad - no language
function example() {}
```
````

### Links

**Use relative links for references:**
```markdown
[See detailed report](reports/skill-name-report.md)
[View code](src/auth/login.js#L45)
```

**Use absolute links for external references:**
```markdown
[CWE-89: SQL Injection](https://cwe.mitre.org/data/definitions/89.html)
```

### Tables

**Use tables for structured data:**

```markdown
| File | Critical | High | Medium | Total |
|------|----------|------|--------|-------|
| file1.js | 2 | 3 | 5 | 10 |
```

### Emojis

**Use emojis sparingly for visual clarity:**

```markdown
⚠️ Critical Issues
⚡ High Priority
📝 Medium Priority
💡 Low Priority
✅ Approve
❌ Request changes
```

**Don't overuse:** One emoji per section heading is sufficient.

## Severity Level Guidelines

### Critical

**Definition:** Issues that must be fixed immediately.

**Examples:**
- Security vulnerabilities (SQL injection, XSS, auth bypass)
- Data loss risks
- Application crashes
- Broken critical functionality

**Response:** Block merge until fixed.

### High

**Definition:** Issues that should be fixed before merge if possible.

**Examples:**
- Performance degradation
- Missing error handling
- Breaking changes
- Significant logic errors

**Response:** Fix before merge or document known issue.

### Medium

**Definition:** Issues that impact maintainability or code quality.

**Examples:**
- Code smells
- Poor naming
- Lack of modularity
- Missing tests

**Response:** Add to technical debt backlog, fix soon.

### Low

**Definition:** Minor issues that don't affect functionality.

**Examples:**
- Style inconsistencies
- Minor optimizations
- Missing comments
- Unused imports

**Response:** Fix in future cleanup, optional.

## Quality Checklist

Before finalizing a report, verify:

**Content:**
- [ ] All sections included and complete
- [ ] Issues have specific file:line references
- [ ] Code examples are accurate
- [ ] Recommendations are actionable
- [ ] Severity levels are justified

**Formatting:**
- [ ] Markdown syntax is correct
- [ ] Code blocks have language tags
- [ ] Links are valid
- [ ] Tables are formatted correctly
- [ ] Consistent use of formatting

**Clarity:**
- [ ] Executive summary is concise
- [ ] Issues are clearly described
- [ ] Recommendations are specific
- [ ] Next steps are actionable

**Completeness:**
- [ ] All issues from individual reports included
- [ ] Duplicates consolidated
- [ ] Statistics accurate
- [ ] Metadata complete
