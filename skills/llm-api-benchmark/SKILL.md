---
name: llm-api-benchmark
description: This skill should be used when the user wants to "test API speed", "benchmark LLM", "check API latency", "measure response time", "test TPS", "benchmark endpoint performance", or wants to evaluate multiple LLM API endpoints' performance metrics.
---

# LLM API Benchmark

Automatically detects the current LLM API endpoint from environment variables and performs performance benchmarking.

## Usage

Simply invoke this skill when you want to benchmark your current LLM API:

```
"Test API speed"
"Run benchmark"
"测试API速度"
"测试响应时间"
```

Or use the command directly:

```bash
python skills/llm-api-benchmark/scripts/benchmark.py
```

## Supported Providers

The tool auto-detects these providers from environment variables:

| Environment Variable | Provider |
|---------------------|----------|
| `ANTHROPIC_API_KEY` | Anthropic/Claude |
| `OPENAI_API_KEY` | OpenAI |
| `AZURE_OPENAI_API_KEY` | Azure OpenAI |
| `GOOGLE_GENERATIVE_AI_API_KEY` | Google Gemini |
| `AWS_ACCESS_KEY_ID` | AWS Bedrock |

## Options

```bash
# List available presets
python benchmark.py --list-presets

# Use preset (recommended for consistent results)
python benchmark.py --preset throughput   # For TPS testing (~300-500 tokens)
python benchmark.py --preset quick        # Fast test (~10 tokens)
python benchmark.py --preset standard     # Medium (~20 tokens)

# Custom iterations
python benchmark.py --iterations 10

# Custom model
python benchmark.py --model gpt-4o

# Custom prompt
python benchmark.py --prompt "Your test prompt"

# Custom output directory
python benchmark.py --output-dir ./my-reports

# Quiet mode (less output)
python benchmark.py --preset throughput -q
```

## Presets

| Preset | Description | Expected Output |
|--------|-------------|-----------------|
| `quick` | Short prompt for fast testing | ~10 tokens |
| `standard` | Medium-length prompt | ~20 tokens |
| `long` | Longer output test | ~100+ tokens |
| `throughput` | High token output for TPS testing | ~300-500 tokens |
| `code` | Programming-related prompt | ~50 tokens |
| `json` | Structured JSON output test | ~30 tokens |

**Recommended**: Use `--preset throughput` for accurate TPS measurement.

## Output

Reports are saved to `reports/llm-benchmark-{timestamp}/`:

```
reports/llm-benchmark-20260227-103000/
├── benchmark-report.md    # Human-readable report
└── benchmark-data.json    # Raw data for programmatic access
```

## Metrics

The benchmark measures:

- **Response Time**: End-to-end latency
- **TTFT** (Time To First Token): Time until first token received
- **TPS** (Tokens Per Second): Token generation throughput

Statistics include: average, min, max, P50, P95, P99

## Example Report

See [../../plans/llm-api-benchmark-plan.md](../../plans/llm-api-benchmark-plan.md) for expected report format.