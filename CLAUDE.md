# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a monorepo for developing Claude Code skills. Skills are modular packages that extend Claude's capabilities with specialized workflows, domain knowledge, and bundled resources.

## Architecture

### Skill Structure

Each skill in `skills/` follows the Claude Code plugin skill architecture:

```
skills/{skill-name}/
├── SKILL.md              # Required: Main skill file with YAML frontmatter
├── references/           # Optional: Detailed documentation loaded as needed
├── examples/             # Optional: Working code examples and templates
└── scripts/              # Optional: Executable utilities
```

### Progressive Disclosure Design

Skills use a three-level loading system to manage context efficiently:

1. **Metadata (always loaded)**: SKILL.md YAML frontmatter with `name` and `description` (~100 words)
2. **SKILL.md body (when triggered)**: Core instructions and workflows (<5,000 words, ideally 1,500-2,000)
3. **Bundled resources (as needed)**: references/, examples/, scripts/ loaded only when required

This keeps initial context small while providing depth when necessary.

### SKILL.md Structure

**YAML Frontmatter (required):**
```yaml
---
name: skill-name
description: This skill should be used when the user asks to "specific phrase 1", "specific phrase 2". Include exact user phrases that should trigger this skill. Use third-person format.
version: 0.1.0
---
```

**Body requirements:**
- Use **imperative/infinitive form** (e.g., "To accomplish X, do Y", not "You should do X")
- Keep lean (1,500-2,000 words)
- Reference supporting files explicitly
- Focus on workflows and procedures

**Description best practices:**
- Use third person: "This skill should be used when..."
- Include specific trigger phrases users would say
- Be concrete about scenarios

**Example good description:**
```yaml
description: This skill should be used when the user asks to "create a hook", "add a PreToolUse hook", "validate tool use", or mentions hook events (PreToolUse, PostToolUse, Stop).
```

### Resource Organization

**references/**: Documentation and reference material (2,000-5,000+ words each)
- Detailed patterns and techniques
- API documentation
- Migration guides
- Load only when Claude determines they're needed

**examples/**: Complete, runnable examples
- Configuration files
- Template code
- Real-world usage samples
- Users can copy and adapt directly

**scripts/**: Executable utilities
- Validation tools
- Automation scripts
- May execute without loading into context
- Should be well-documented and error-handled

## Development Commands

### Testing Skills Locally

```bash
# Test skills with Claude Code
cc --plugin-dir /path/to/my-skills

# Trigger a skill by asking questions
# e.g., "Review the feature/auth branch compared to dev"
```

### Creating New Skills

```bash
# 1. Create skill directory structure
mkdir -p skills/your-skill/{references,examples,scripts}
touch skills/your-skill/SKILL.md

# 2. Write SKILL.md following structure above

# 3. Add supporting resources as needed

# 4. Test with cc --plugin-dir
```

### Making Scripts Executable

```bash
chmod +x skills/*/scripts/*.sh
```

## Key Principles

### Writing Style

- **Imperative form throughout**: "Start by reading the file", not "You should start by reading"
- **Third-person in description**: "This skill should be used when...", not "Use this skill when..."
- **Objective, instructional language**: "Parse the frontmatter using sed", not "You can parse..."

### Content Organization

- **SKILL.md is lean**: Core essentials only, move details to references/
- **Don't duplicate**: Information lives in either SKILL.md or references/, not both
- **Reference explicitly**: Always link to supporting files from SKILL.md

### Quality Standards

- **Specific trigger phrases**: Include exact user queries in description
- **Working examples**: All examples must be complete and runnable
- **Documented scripts**: Scripts should have clear usage instructions
- **Error handling**: Scripts should handle edge cases gracefully

## Existing Skills

This repository contains code review skills with a two-skill architecture:

### code-review:config-manager

**Configuration manager for code review skills.**

Manages review skills configuration, skill discovery, presets, and validation.

**Configuration System:**
- Three-tier priority: project > user > global
- Locations:
  - Project: `.claude/code-review-skills/config.yaml`
  - User: `~/.claude/code-review-skills/config.yaml`
  - Global: `~/.config/claude/code-review-skills/config.yaml`

**Key features:**
- Skill auto-discovery and categorization
- Preset management (create, edit, delete presets)
- Configuration validation and merging
- Multi-tier configuration support

**Bundled scripts:**
- `scripts/init-config.sh` - Initialize configuration files
- `scripts/discover-skills.sh` - Auto-discover review skills
- `scripts/validate-config.sh` - Validate YAML syntax and structure
- `scripts/merge-configs.sh` - Merge multi-tier configurations

**Directory:** [skills/code-review:config-manager/](skills/code-review:config-manager/)

### code-review:executor

**Code review executor with parallel skill orchestration.**

Executes parallel code reviews using configured presets from config-manager.

**Key workflow:**
1. Load and validate configuration file
2. Select review preset
3. Collect code content (diffs, commits, branches)
4. Coordinate multiple subagents using configured skills
5. Consolidate reports into comprehensive summary

**Bundled scripts:**
- `scripts/collect-review-data.sh` - Collect code data
- `scripts/find-merge-base.sh` - Find merge base for branch comparison

**Directory:** [skills/code-review:executor/](skills/code-review:executor/)

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    code-review:executor                      │
│              (Review Execution & Orchestration)              │
├─────────────────────────────────────────────────────────────┤
│  1. Load configuration from config-manager                   │
│  2. Select review preset                                     │
│  3. Collect code content (diffs, commits, branches)          │
│  4. Launch parallel subagents with configured skills         │
│  5. Consolidate reports into comprehensive summary           │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 code-review:config-manager                   │
│                (Configuration Management)                    │
├─────────────────────────────────────────────────────────────┤
│  • Three-tier configuration (project > user > global)        │
│  • Auto-discover available review skills                     │
│  • Manage presets (quick review, full review, security...)   │
│  • Validate configuration files                              │
└─────────────────────────────────────────────────────────────┘
```

**Installation:**
```bash
# Install both skills for configuration-driven reviews
npx skills add ridewind/my-skills --skill code-review:config-manager -g -y
npx skills add ridewind/my-skills --skill code-review:executor -g -y
```

## Important Files

- **README.md**: Project overview and quick start guide
- **CLAUDE.md**: This file - architecture and development guidance
- **skills/**: All skill directories
- **LICENSE**: Project license

## Testing Approach

When testing skills:
1. Use `cc --plugin-dir .` to load skills
2. Trigger skills with phrases from their description
3. Verify skill loads and provides correct guidance
4. Check that referenced files exist and are accessible
5. Validate scripts execute correctly

## Common Patterns

### Skill Description Template

```yaml
description: This skill should be used when the user asks to "verb noun1", "verb noun2", "verb noun3", or mentions [specific concept/term]. [Brief clarification of scope].
```

### Referencing Resources in SKILL.md

```markdown
## Additional Resources

### Reference Files
- **`references/patterns.md`** - Detailed patterns guide
- **`references/advanced.md`** - Advanced techniques

### Examples
- **`examples/template.js`** - Working example
- **`examples/config.json`** - Sample configuration

### Scripts
- **`scripts/validate.sh`** - Validation utility
```

### Subagent Coordination Pattern

When coordinating multiple subagents:
1. Launch all subagents in a single message using multiple Task tool calls
2. Use `run_in_background=true` for parallel execution
3. Save each subagent's output to a unique file
4. Wait for all to complete using TaskOutput tool
5. Read and consolidate all results

See `code-review:executor/references/subagent-coordination.md` for detailed patterns.

### Review Working Directory Pattern

Code review skills use a standardized directory naming convention to avoid conflicts:

**Format:** `{review_name}-{YYYYMMDD}-{sequence}`

**Generation logic:**
```bash
DATE=$(date +%Y%m%d)
BASE_DIR="{review_name}-${DATE}"
EXISTING=$(ls -d reviews/${BASE_DIR}-* 2>/dev/null | wc -l)
SEQUENCE=$((EXISTING + 1))
WORKING_DIR="${BASE_DIR}-${SEQUENCE}"
```

**Directory structure:**
```
reviews/{review_name}-{YYYYMMDD}-{sequence}/
├── code-context.json                     # Review metadata
├── diff.patch                             # Git diff output
├── commits.json                           # Commit history
├── branch-info.json                       # Branch details
├── DEBUG-SESSION.md                       # Debug session log (optional)
├── {review_name}-{YYYYMMDD}-{sequence}-comprehensive-summary.md # Final report
└── reports/                               # Individual skill reports
    ├── skill1-report.md
    ├── skill2-report.md
    └── ...
```

**File naming conventions:**
- **Working directory**: `{review_name}-{YYYYMMDD}-{sequence}` (date + sequence for uniqueness)
- **Summary file**: `{review_name}-{YYYYMMDD}-{sequence}-comprehensive-summary.md` (include date+sequence)
- **Debug session file**: `DEBUG-SESSION.md` (always uppercase, fixed name)
- **Individual reports**: `{skill-name}-report.md` (use skill's short name)
- **Context files**: lowercase with hyphens (code-context.json, diff.patch, etc.)
