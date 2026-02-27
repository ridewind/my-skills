# LLM API Benchmark Report

## Test Information
- **Time**: 2026-02-27T10:30:00.123456
- **Provider**: Anthropic
- **Endpoint**: https://api.anthropic.com/v1/messages
- **Model**: claude-sonnet-4-20250514
- **Prompt**: Count from 1 to 10, one number per line. Just output the numbers.
- **Iterations**: 5

## Performance Metrics

### Response Time (seconds)
| Metric | Value |
|--------|-------|
| Average | 0.847s |
| Minimum | 0.723s |
| Maximum | 1.012s |
| P50 | 0.835s |
| P95 | 1.012s |
| P99 | 1.012s |

### Time to First Token (TTFT)
| Metric | Value |
|--------|-------|
| Average | 0.342s |
| Minimum | 0.289s |
| Maximum | 0.401s |

### Tokens Per Second (TPS)
| Metric | Value |
|--------|-------|
| Average | 28.45 |
| Minimum | 24.12 |
| Maximum | 32.67 |

**Total Tokens**: 120

## Detailed Results

| # | Response Time | TTFT | Tokens | TPS | Status |
|---|---------------|------|--------|-----|--------|
| 1 | 0.823s | 0.312s | 24 | 29.12 | OK |
| 2 | 0.723s | 0.289s | 24 | 32.67 | OK |
| 3 | 1.012s | 0.401s | 24 | 24.12 | OK |
| 4 | 0.835s | 0.345s | 24 | 28.74 | OK |
| 5 | 0.842s | 0.362s | 24 | 27.61 | OK |
