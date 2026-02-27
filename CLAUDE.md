# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Navigation

- [Repository Purpose](#repository-purpose) - What this monorepo contains
- [Core Principles](#core-principles) - Development philosophy and guidelines
- [Tech Stack](#tech-stack) - Technologies and tools used
- [Architecture](#architecture) - Skill structure and design patterns
- [Workflow Instructions](#workflow-instructions) - How to work with this codebase
- [Existing Skills](#existing-skills) - Available skills and their features
- [Common Patterns](#common-patterns) - Reusable patterns and conventions

## Repository Purpose

This is a monorepo for developing Claude Code skills. Skills are modular packages that extend Claude's capabilities with specialized workflows, domain knowledge, and bundled resources.

## Core Principles

### Development Philosophy

1. **Progressive Disclosure**: Load information only when needed to minimize context usage
2. **Modularity**: Each skill should be self-contained and independently usable
3. **Imperative Style**: Use imperative/infinitive form in skill instructions ("Do X", not "You should do X")
4. **Third-Person Descriptions**: Skill descriptions use third-person ("This skill should be used when...")
5. **No Duplication**: Information should live in one place; reference explicitly instead of duplicating

### Quality Standards

- **Specific trigger phrases**: Include exact user queries that should trigger the skill
- **Working examples**: All examples must be complete and runnable
- **Documented scripts**: Scripts should have clear usage instructions and error handling
- **Lean SKILL.md**: Keep core skill files focused (1,500-2,000 words ideally)
- **Context efficiency**: Use three-level loading system (metadata → body → resources)

### File Writing Guidelines (Code Review Skills)

Code review skills must follow specific rules to minimize authorization prompts:
1. **Prioritize Scripts**: Use existing scripts for data collection
2. **Use Write Tool**: For manual file creation instead of Bash redirection
3. **Bash for Queries Only**: Use Bash for read-only operations and script execution

## Tech Stack

### Languages
- **Python**: Primary language for skill scripts and utilities
- **Shell**: Bash scripts for automation and validation
- **YAML**: Configuration files and skill frontmatter

### Tools & Frameworks
- **Claude Code**: Primary development environment
- **npx skills**: Skill package management and distribution
- **Git**: Version control with branching strategies

### Skill Types
- **Code Review Skills**: config-manager, executor
- **Benchmarking Tools**: llm-api-benchmark
- **Workflow Skills**: Various specialized skills for development tasks

## Workflow Instructions

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

### Development Workflow

1. **Understand the requirement**: What problem should the skill solve?
2. **Design the skill structure**: Plan SKILL.md, references/, examples/, scripts/
3. **Write SKILL.md**: Follow the template with proper YAML frontmatter
4. **Add resources**: Create supporting files as needed
5. **Test locally**: Use `cc --plugin-dir .` to verify
6. **Distribute**: Publish via npx skills or install directly

### Common Development Commands

| Task | Command |
|------|---------|
| Test skills | `cc --plugin-dir .` |
| Create skill | `mkdir -p skills/your-skill/{references,examples,scripts}` |
| Make executable | `chmod +x skills/*/scripts/*.sh` |
| Install skill globally | `npx skills add user/repo --skill skill-name -g -y` |

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
- Designed to minimize file write operations in skills

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
  - `--force` / `-f`: Force overwrite existing config without prompts
  - `--skip-discover` / `-s`: Skip auto-discovery of skills
  - `--global` / `--user` / `--project`: Set configuration level (default: project)
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
3. Collect code content using scripts (prefer `collect-review-data.sh`), fallback to Write tool
4. Coordinate multiple subagents using configured skills
5. Use Write tool to save all reports and summaries

**File Writing Approach:**
- **Priority**: Use `scripts/collect-review-data.sh` for data collection (one-time operation)
- **Fallback**: Use Write tool for manual file creation when scripts unavailable
- **Avoid**: Bash commands with redirection (`cat > file`, `echo > file`)

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

### llm-api-benchmark

**LLM API performance benchmarking tool.**

Automatically detects current LLM API endpoint from environment variables and performs performance benchmarking.

**Features:**
- Auto-detect LLM providers (Anthropic, OpenAI, Azure, Google Gemini, AWS Bedrock)
- Measure response time, TTFT (Time To First Token), TPS (Tokens Per Second)
- Multiple preset prompts for different test scenarios
- Markdown and JSON report output

**Default Behavior:**
- **Preset**: `code` (~500-1000 tokens, optimized for coding workflows)
- **Iterations**: 5
- **Output**: `reports/llm-benchmark-{timestamp}/`

**Bundled scripts:**
- `scripts/benchmark.py` - Main benchmark script (Python standard library only)

**Usage:**
```bash
# Run with default (code preset)
python skills/llm-api-benchmark/scripts/benchmark.py

# List available presets
python skills/llm-api-benchmark/scripts/benchmark.py --list-presets

# Run benchmark with preset
python skills/llm-api-benchmark/scripts/benchmark.py --preset throughput

# Custom iterations
python skills/llm-api-benchmark/scripts/benchmark.py --iterations 10
```

**Presets:**
| Preset | Description | Expected Output |
|--------|-------------|-----------------|
| `quick` | Short prompt for fast testing | ~10 tokens |
| `standard` | Medium-length prompt | ~20 tokens |
| `long` | Longer output test | ~100+ tokens |
| `throughput` | High token output for TPS testing | ~300-500 tokens |
| `code` | Programming-related prompt (default) | ~500-1000 tokens |
| `json` | Structured JSON output test | ~30 tokens |

**Directory:** [skills/llm-api-benchmark/](skills/llm-api-benchmark/)

**Example Report:** [skills/llm-api-benchmark/examples/benchmark-report-example.md](skills/llm-api-benchmark/examples/benchmark-report-example.md)

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
