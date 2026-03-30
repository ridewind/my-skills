# Code Review Executor - Quick Reference

## 7-Step Workflow Overview

| Step | Action | Key Tools |
|------|--------|-----------|
| 0 | Debug Mode Detection | Check for debug keywords |
| 1 | Load Config | Find config files, validate YAML |
| 2 | Determine Scope | Branch comparison, MR/PR, or project-wide |
| 3 | Create Working Dir | Format: `{name}-{YYYYMMDD}-{seq}` |
| 4 | Select Preset | AskUserQuestion for preset selection |
| 5 | Collect Code | Run `collect-review-data.sh` |
| 6 | Parallel Execution | Task tool with `run_in_background=true` |
| 7 | Consolidate Results | Read reports, dedupe, generate summary |

## Key Commands

### Data Collection
```bash
# Branch comparison
bash scripts/collect-review-data.sh -s feature/auth -t dev -o ./reviews/auth

# MR/PR review (GitHub)
bash scripts/collect-review-data.sh -p 123 -o ./reviews/pr-123

# MR/PR review (GitLab)
bash scripts/collect-review-data.sh -m 456 -o ./reviews/mr-456
```

### Launch Subagents
```bash
# With adaptive timeout
bash scripts/launch-subagents.sh -w ./reviews/auth -s "skill1,skill2" -t auto
```

## Timeout Guide

| Code Size | Timeout |
|-----------|---------|
| Small (<500 lines) | 60s |
| Medium (500-2000) | 180s |
| Large (2000-10000) | 300s |
| Very Large (>10000) | 600s |

## Output Directory Structure

```
reviews/{name}-{date}-{seq}/
├── code-context.json      # Review metadata
├── diff.patch             # Git diff
├── commits.json           # Commit history
├── branch-info.json       # Branch details
├── DEBUG-SESSION.md       # Debug log (optional)
├── {name}-{date}-{seq}-comprehensive-summary.md
└── reports/
    ├── {skill1}-report.md
    └── {skill2}-report.md
```

## Error Handling Checklist

- [ ] Verify config file exists
- [ ] Check git repository
- [ ] Validate branches exist
- [ ] Verify skills are available
- [ ] Handle partial subagent failures
- [ ] Document any missing coverage

## Report Requirements

Every issue must include:
1. **Found by** - Which skill discovered it
2. **File:Line** - Location
3. **Severity** - Critical/High/Medium/Low/Info
4. **Description** - What's wrong
5. **Recommendation** - How to fix
