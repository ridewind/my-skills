# My Skills

A monorepo of Claude Code skills for specialized workflows and code review orchestration.

## Skills

### code-review:config-manager

**Configuration manager for code review skills.**

Manages review skills configuration, skill discovery, presets, and validation.

**When to use:**
- "Manage review skills config"
- "Update review skills"
- "Discover review skills"
- "Manage review presets"
- "Validate review config"

**Features:**
- Three-tier configuration priority (project > user > global)
- Automatic skill discovery and categorization
- Preset management (create, edit, delete presets)
- Configuration validation and merging

**Configuration Locations:**
- Project: `.claude/code-review-skills/config.yaml`
- User: `~/.claude/code-review-skills/config.yaml`
- Global: `~/.config/claude/code-review-skills/config.yaml`

**Directory:** [skills/code-review:config-manager/](skills/code-review:config-manager/)

---

### code-review:executor

**Code review executor with preset-based skill orchestration.**

Executes parallel code reviews using configured presets from config-manager.

**When to use:**
- "Review my code"
- "Review feature/auth branch"
- "Review MR !1234" / "Review PR #567"
- "Review feature/auth vs dev branch"
- "Do a code review"

**Features:**
- Branch comparison with proper merge-base detection
- Support for GitLab MR and GitHub PR reviews
- Multi-skill parallel review execution
- Comprehensive issue categorization (Critical, High, Medium, Low)
- Debug mode with detailed session logging

**Directory:** [skills/code-review:executor/](skills/code-review:executor/)

---

### llm-api-benchmark

**LLM API performance benchmarking tool.**

Automatically detects current LLM API endpoint from environment variables and performs performance benchmarking.

**When to use:**
- "Test API speed"
- "Benchmark LLM"
- "Check API latency"
- "Measure response time"
- "Test TPS"
- "测试 API 速度"

**Features:**
- Auto-detect LLM providers (Anthropic, OpenAI, Azure, Google Gemini, AWS Bedrock)
- Measure response time, TTFT (Time To First Token), TPS (Tokens Per Second)
- Multiple preset prompts for different test scenarios
- Markdown and JSON report output
- Python standard library only (no dependencies)

**Quick Start:**
```bash
# List available presets
python skills/llm-api-benchmark/scripts/benchmark.py --list-presets

# Run benchmark with throughput preset (recommended for TPS testing)
python skills/llm-api-benchmark/scripts/benchmark.py --preset throughput

# Quick test
python skills/llm-api-benchmark/scripts/benchmark.py --preset quick

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
| `code` | Programming-related prompt | ~50 tokens |
| `json` | Structured JSON output test | ~30 tokens |

**Directory:** [skills/llm-api-benchmark/](skills/llm-api-benchmark/)

---

## Architecture

The code review system uses a two-skill architecture:

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

## Quick Start

### 1. Initialize Configuration

```
Manage review skills config
```

This will:
- Create configuration file at project/user/global level
- Auto-discover available review skills
- Set up default presets

### 2. Execute Code Review

```
Review the feature/auth branch compared to dev
```

The executor will:
- Load configuration and presets
- Ask you to select a preset
- Collect code diff, commits, and metadata
- Launch parallel subagents for review
- Generate consolidated summary report

### 3. Review Output

- Individual skill reports: `{workdir}/reports/`
- Consolidated summary: `{workdir}/{review-name}-comprehensive-summary.md`
- Debug session log: `{workdir}/DEBUG-SESSION.md` (if debug mode enabled)

## Project Structure

```
my-skills/
├── skills/
│   ├── code-review:config-manager/
│   │   ├── SKILL.md              # Main skill instructions
│   │   ├── references/           # Detailed reference docs
│   │   └── scripts/
│   │       ├── init-config.sh    # Initialize configuration
│   │       ├── discover-skills.sh # Auto-discover skills
│   │       ├── validate-config.sh # Validate configuration
│   │       └── merge-configs.sh  # Merge multi-tier configs
│   │
│   └── code-review:executor/
│       ├── SKILL.md              # Main skill instructions
│       ├── references/           # Detailed reference docs
│       └── scripts/
│           ├── collect-review-data.sh  # Collect git data
│           └── find-merge-base.sh      # Find merge base
│
├── CLAUDE.md                     # Project instructions
└── README.md                     # This file
```

## Development

### Adding a New Skill

1. Create skill directory:
   ```bash
   mkdir -p skills/your-skill/{references,examples,scripts}
   touch skills/your-skill/SKILL.md
   ```

2. Write SKILL.md with:
   - YAML frontmatter (name, description with trigger phrases)
   - Skill instructions (1,500-2,000 words)
   - References to supporting files

3. Add supporting resources:
   - `references/` - Detailed documentation
   - `examples/` - Working examples
   - `scripts/` - Utility scripts

4. Test the skill:
   ```bash
   cc --plugin-dir /path/to/my-skills
   ```

### Best Practices

- **Progressive Disclosure:** Keep SKILL.md lean, move details to references/
- **Imperative Form:** Use verb-first instructions (not "you should")
- **Third-Person Description:** "This skill should be used when..."
- **Specific Triggers:** Include exact user phrases in description
- **Working Examples:** Provide complete, runnable examples

## Contributing

This is a personal skills repository. Contributions are not currently accepted.

## License

See [LICENSE](LICENSE) file for details.