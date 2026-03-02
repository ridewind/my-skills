---
name: llm-api-benchmark
description: This skill should be used when the user wants to "test API speed", "benchmark LLM", "check API latency", "measure response time", "test TPS", "benchmark endpoint performance", "测试当前端点", "测试LLM速度", or wants to evaluate multiple LLM API endpoints' performance metrics.
---

# LLM API Benchmark

Performance benchmarking tool for LLM API endpoints with two modes:
1. **HTTP Mode** (default): Direct API calls for precise TTFT/TPS measurement
2. **Subagent Mode**: Use Claude subagents to test current endpoint via `cc-switch`

## Quick Start

### Method 1: HTTP Mode (Direct API)

For accurate TTFT/TPS with direct API calls:

```bash
# Auto-detect endpoint from environment
python skills/llm-api-benchmark/scripts/benchmark.py

# Test specific preset
python skills/llm-api-benchmark/scripts/benchmark.py --preset throughput
```

### Method 2: Subagent Mode (via cc-switch)

For testing endpoints configured via `cc-switch`:

```bash
# 1. Switch to your endpoint
cc-switch openai-proxy

# 2. Run benchmark in Claude Code
"测试当前端点性能"
"Benchmark current endpoint"

# 3. Switch to another endpoint
cc-switch gemini-local

# 4. Test again
"测试当前端点性能"

# 5. Compare results
"对比端点性能"
```

## Subagent Mode (New)

### How It Works

1. **Main session** (current Claude) launches subagent via Task tool
2. **Subagent** executes a real task (code generation, documentation)
3. **Main session** measures Task execution time
4. **Multiple iterations** for statistical accuracy
5. **Results saved** for cross-endpoint comparison

### Workflow

```
User: "测试当前端点性能"
   │
   ▼
Main Session
   ├─ Record start time
   ├─ Launch Subagent (Task tool) ────┐
   │                                  │
   │   Subagent executes:            │
   │   "Generate Python quicksort"   │
   │   (Triggers LLM call)           │
   │                                  │
   ├─ Wait completion ◄──────────────┘
   ├─ Record end time
   └─ Calculate elapsed time

Repeat 5× → Statistics → Save Result
```

### Usage

```python
# In SKILL.md - Subagent benchmark execution
import time
import json
from datetime import datetime
from pathlib import Path

def benchmark_with_subagent(iterations=5, task="code"):
    """Benchmark current endpoint using subagent"""

    # Task definitions
    TASKS = {
        "code": "Generate a Python quicksort implementation with type hints and docstrings",
        "doc": "Write technical documentation about REST APIs (300+ words)",
        "analysis": "Analyze a Python function and explain its complexity",
        "refactor": "Refactor poorly written code to be more Pythonic"
    }

    results = []
    task_prompt = TASKS.get(task, TASKS["code"])

    print(f"Benchmarking with task: {task}")
    print(f"Iterations: {iterations}")
    print("-" * 50)

    for i in range(iterations):
        print(f"  Iteration {i+1}/{iterations}...", end=" ")

        start_time = time.time()

        # Launch subagent to execute task
        result = Task(
            prompt=f'''Execute this task using the current LLM endpoint:

Task: {task_prompt}

Steps:
1. Think through the problem
2. Generate the content
3. Return your result

Note: This task is being benchmarked. Please respond naturally.''',
            subagent_type="general-purpose",
            run_in_background=False
        )

        elapsed = time.time() - start_time
        results.append(elapsed)

        print(f"{elapsed:.2f}s")

    # Calculate statistics
    stats = {
        "timestamp": datetime.now().isoformat(),
        "endpoint": get_current_endpoint(),  # From environment
        "task": task,
        "iterations": iterations,
        "avg_time": sum(results) / len(results),
        "min_time": min(results),
        "max_time": max(results),
        "times": results
    }

    # Save for comparison
    save_benchmark_result(stats)

    return stats

def save_benchmark_result(stats):
    """Save result for cross-endpoint comparison"""
    output_dir = Path("reports/llm-benchmark-subagent")
    output_dir.mkdir(parents=True, exist_ok=True)

    # Sanitize endpoint name for filename
    endpoint_name = stats["endpoint"].replace("://", "_").replace("/", "_")
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")

    file_path = output_dir / f"{endpoint_name}_{timestamp}.json"

    with open(file_path, 'w') as f:
        json.dump(stats, f, indent=2)

    print(f"\nResult saved: {file_path}")

def compare_endpoints():
    """Compare all saved benchmark results"""
    import glob

    results_dir = Path("reports/llm-benchmark-subagent")
    if not results_dir.exists():
        print("No benchmark results found.")
        return

    # Load all results
    results = []
    for file_path in results_dir.glob("*.json"):
        with open(file_path) as f:
            results.append(json.load(f))

    if len(results) < 2:
        print(f"Found {len(results)} result(s). Need at least 2 for comparison.")
        return

    # Sort by average time, fastest first
    results.sort(key=lambda x: x["avg_time"])

    # Display comparison
    print("\n" + "=" * 70)
    print("ENDPOINT COMPARISON")
    print("=" * 70)
    print(f"{'Endpoint':<40} {'Avg Time':<12} {'Min':<10} {'Max':<10}")
    print("-" * 70)

    baseline = results[0]["avg_time"]

    for r in results:
        endpoint = r["endpoint"][:38]
        avg = f"{r['avg_time']:.2f}s"
        min_t = f"{r['min_time']:.2f}s"
        max_t = f"{r['max_time']:.2f}s"

        speedup = baseline / r["avg_time"]
        indicator = "⚡ baseline" if speedup >= 0.95 else f"{speedup:.1f}× slower"

        print(f"{endpoint:<40} {avg:<12} {min_t:<10} {max_t:<10} {indicator}")

    print("=" * 70)
```

### Example Output

```
Benchmarking with task: code
Iterations: 5
--------------------------------------------------
  Iteration 1/5... 1.23s
  Iteration 2/5... 1.15s
  Iteration 3/5... 1.31s
  Iteration 4/5... 1.18s
  Iteration 5/5... 1.25s

Result saved: reports/llm-benchmark-subagent/api_anthropic_com_20260302-103052.json

Statistics:
  Average: 1.22s
  Min:     1.15s
  Max:     1.31s
```

## Comparison Report

After testing multiple endpoints:

```
======================================================================
ENDPOINT COMPARISON
======================================================================
Endpoint                                 Avg Time     Min        Max
----------------------------------------------------------------------
localhost_8080                           0.82s        0.78s      0.89s   ⚡ baseline
api_anthropic_com                        1.23s        1.15s      1.31s   1.5× slower
192_168_1_100_8080                       2.45s        2.30s      2.60s   3.0× slower
======================================================================
```

## HTTP Mode (Original)

### Direct API Benchmarking

For precise measurements including TTFT and TPS:

```bash
python skills/llm-api-benchmark/scripts/benchmark.py [options]
```

### Options

| Option | Description |
|--------|-------------|
| `--iterations N` | Number of iterations (default: 5) |
| `--preset NAME` | Use preset prompt (quick/standard/long/throughput/code/json) |
| `--prompt TEXT` | Custom prompt |
| `--model MODEL` | Override model name |
| `--output-dir DIR` | Output directory (default: reports) |
| `--quiet` | Suppress progress output |

### Presets

| Preset | Description | Expected Output |
|--------|-------------|-----------------|
| `quick` | Short prompt for fast testing | ~10 tokens |
| `standard` | Medium-length prompt | ~20 tokens |
| `long` | Longer output test | ~100+ tokens |
| `throughput` | High token output for TPS testing | ~300-500 tokens |
| `code` | Programming-related prompt (default) | ~500-1000 tokens |
| `json` | Structured JSON output test | ~30 tokens |

### Output

```
reports/llm-benchmark-{timestamp}/
├── benchmark-report.md    # Human-readable report
└── benchmark-data.json    # Raw data
```

## Log Analysis (Optional Enhancement)

For more precise timing, enable Claude debug mode:

```bash
# Enable debug logging
export CLAUDE_DEBUG=1

# Run benchmark (subagent mode)
"测试当前端点性能"

# Parse logs for precise timing
python skills/llm-api-benchmark/scripts/parse-claude-logs.py --last-minutes 5
```

### Log Parser Usage

```bash
# Parse last 5 minutes
python parse-claude-logs.py --last-minutes 5

# Parse specific session
python parse-claude-logs.py --session-start 2026-03-02T10:00:00

# Output as JSON
python parse-claude-logs.py --last-minutes 5 --json
```

## Metrics Explained

| Metric | Description | Mode |
|--------|-------------|------|
| **Response Time** | Total time from request to completion | Both |
| **TTFT** | Time To First Token (processing latency) | HTTP only |
| **TPS** | Tokens Per Second (generation throughput) | HTTP only |
| **Relative Speed** | Comparison to baseline endpoint | Subagent |

## When to Use Which Mode

| Use Case | Recommended Mode | Why |
|----------|-----------------|-----|
| Compare `cc-switch` endpoints | **Subagent** | Uses current Claude configuration |
| Measure exact TTFT/TPS | **HTTP** | Direct API access with streaming |
| Test without API keys | **Subagent** | Uses existing Claude session |
| Quick relative comparison | **Subagent** | Simpler setup |
| Precise token metrics | **HTTP** | Accurate token counting |

## Supported Providers (HTTP Mode)

Auto-detected from environment:

| Variable | Provider |
|----------|----------|
| `ANTHROPIC_API_KEY` | Anthropic/Claude |
| `OPENAI_API_KEY` | OpenAI |
| `AZURE_OPENAI_API_KEY` | Azure OpenAI |
| `GOOGLE_GENERATIVE_AI_API_KEY` | Google Gemini |
| `AWS_ACCESS_KEY_ID` | AWS Bedrock |

## Files

- `scripts/benchmark.py` - HTTP mode benchmarking
- `scripts/benchmark-subagent.py` - Subagent task definitions
- `scripts/parse-claude-logs.py` - Debug log analyzer
- `examples/benchmark-report-example.md` - Sample report
