#!/usr/bin/env python3
"""
LLM API Benchmark Tool

Auto-detects current LLM API endpoint from environment variables and performs
performance benchmarking including response time, TTFT, and TPS.

Usage:
    python benchmark.py [--iterations N] [--model MODEL] [--prompt PROMPT]
    python benchmark.py --preset quick        # Quick test (short prompt)
    python benchmark.py --preset throughput   # High output for TPS testing
    python benchmark.py --preset code         # Code generation (default)

Default: Uses 'code' preset (~500-1000 tokens) for coding workflows.
"""

import os
import sys
import json
import time
import re
import argparse
import statistics
import socket
import http.client
from dataclasses import dataclass, asdict, field
from datetime import datetime
from typing import Optional
from pathlib import Path
from urllib.parse import urlparse


# Preset prompts for consistent benchmarking
# These prompts are designed to produce relatively fixed-length outputs
PRESET_PROMPTS = {
    "quick": {
        "name": "Quick Test",
        "description": "Short prompt for fast testing (~10 tokens)",
        "prompt": "Write a single sentence greeting.",
    },
    "standard": {
        "name": "Standard Test",
        "description": "Medium-length prompt (~20 tokens)",
        "prompt": "Count from 1 to 10, one number per line. Just output the numbers.",
    },
    "long": {
        "name": "Long Output Test",
        "description": "Longer output test (~100+ tokens)",
        "prompt": "Write a detailed paragraph about Python programming. Include at least 5 sentences about its features, history, and popular use cases.",
    },
    "throughput": {
        "name": "Throughput Test",
        "description": "High token output for TPS testing (~300-500 tokens)",
        "prompt": """Write a comprehensive technical article about REST APIs. Cover:
1. What is REST and its core principles
2. HTTP methods and status codes
3. Best practices for API design
4. Common authentication methods
5. Rate limiting and pagination
6. Error handling strategies
7. Versioning approaches
8. Testing methodologies

Be thorough and detailed in each section. Output as much content as possible.""",
    },
    "code": {
        "name": "Code Test",
        "description": "Programming-related prompt (~500-1000 tokens)",
        "prompt": """Write a complete, production-ready Python class that implements a thread-safe LRU cache with the following features:
1. Fixed capacity with automatic eviction of least recently used items
2. Thread-safe operations using proper locking
3. O(1) get and put operations
4. Configurable capacity via constructor
5. Clear method to empty the cache
6. Size method to return current item count
7. Comprehensive docstrings for all methods
8. Type hints throughout

Include thorough error handling and usage examples in the docstring.
Make the implementation robust and well-commented.""",
    },
    "json": {
        "name": "JSON Test",
        "description": "Structured JSON output test (~30 tokens)",
        "prompt": 'Output valid JSON with fields: name="test", value=123, active=true. No explanation.',
    },
}


@dataclass
class APIConfig:
    """Detected API configuration"""
    provider: str
    endpoint: str
    api_key: str
    model: str
    headers: dict = field(default_factory=dict)


@dataclass
class RequestResult:
    """Single request result"""
    iteration: int
    success: bool
    response_time: float  # Total response time in seconds
    ttft: float  # Time to first token
    tokens: int
    tps: float  # Tokens per second
    error: Optional[str] = None


@dataclass
class BenchmarkReport:
    """Complete benchmark report"""
    timestamp: str
    provider: str
    endpoint: str
    model: str
    prompt: str
    iterations: int

    # Response time stats
    avg_response_time: float
    min_response_time: float
    max_response_time: float
    p50_response_time: float
    p95_response_time: float
    p99_response_time: float

    # TTFT stats
    avg_ttft: float
    min_ttft: float
    max_ttft: float

    # TPS stats
    avg_tps: float
    min_tps: float
    max_tps: float

    # Summary
    total_tokens: int
    success_count: int
    failure_count: int

    # Detailed results
    results: list = field(default_factory=list)


def detect_api_config() -> Optional[APIConfig]:
    """Detect current LLM API from environment variables"""

    # Check Anthropic/Claude API
    api_key = os.environ.get('ANTHROPIC_API_KEY') or os.environ.get('ANTHROPIC_API_KEY_DEV') or os.environ.get('ANTHROPIC_AUTH_TOKEN')
    if api_key:
        base_url = os.environ.get('ANTHROPIC_BASE_URL', 'https://api.anthropic.com')
        model = os.environ.get('ANTHROPIC_MODEL') or os.environ.get('ANTHROPIC_DEFAULT_SONNET_MODEL', 'claude-sonnet-4-20250514')
        return APIConfig(
            provider='Anthropic',
            endpoint=f"{base_url}/v1/messages",
            api_key=api_key,
            model=model,
            headers={
                'x-api-key': api_key,
                'anthropic-version': '2023-06-01',
                'content-type': 'application/json'
            }
        )

    # Check OpenAI
    api_key = os.environ.get('OPENAI_API_KEY')
    if api_key:
        base_url = os.environ.get('OPENAI_BASE_URL', 'https://api.openai.com/v1')
        model = os.environ.get('OPENAI_MODEL', 'gpt-4o')
        return APIConfig(
            provider='OpenAI',
            endpoint=f"{base_url}/chat/completions",
            api_key=api_key,
            model=model,
            headers={
                'Authorization': f'Bearer {api_key}',
                'content-type': 'application/json'
            }
        )

    # Check Azure OpenAI
    api_key = os.environ.get('AZURE_OPENAI_API_KEY')
    endpoint = os.environ.get('AZURE_OPENAI_ENDPOINT')
    deployment = os.environ.get('AZURE_OPENAI_DEPLOYMENT_NAME')
    if api_key and endpoint and deployment:
        return APIConfig(
            provider='Azure OpenAI',
            endpoint=f"{endpoint}/openai/deployments/{deployment}/chat/completions?api-version=2024-02-15-preview",
            api_key=api_key,
            model=deployment,
            headers={
                'api-key': api_key,
                'content-type': 'application/json'
            }
        )

    # Check Google Gemini
    api_key = os.environ.get('GOOGLE_GENERATIVE_AI_API_KEY')
    if api_key:
        base_url = os.environ.get('GOOGLE_GENERATIVE_AI_BASE_URL', 'https://generativelanguage.googleapis.com')
        model = os.environ.get('GOOGLE_GENERATIVE_AI_MODEL', 'gemini-2.0-flash')
        return APIConfig(
            provider='Google Gemini',
            endpoint=f"{base_url}/v1beta/models/{model}:generateContent",
            api_key=api_key,
            model=model,
            headers={
                'content-type': 'application/json'
            }
        )

    # Check AWS Bedrock
    if os.environ.get('AWS_ACCESS_KEY_ID'):
        return APIConfig(
            provider='AWS Bedrock',
            endpoint='bedrock-runtime',
            api_key='bedrock',
            model=os.environ.get('BEDROCK_MODEL', 'anthropic.claude-3-sonnet-20240229-v1:0'),
            headers={}
        )

    return None


def build_payload(config: APIConfig, prompt: str) -> dict:
    """Build API request payload based on provider"""

    if config.provider == 'Anthropic':
        return {
            'model': config.model,
            'messages': [{'role': 'user', 'content': prompt}],
            'max_tokens': 256,
            'stream': True
        }

    elif config.provider == 'OpenAI' or config.provider == 'Azure OpenAI':
        return {
            'model': config.model,
            'messages': [{'role': 'user', 'content': prompt}],
            'max_tokens': 256,
            'stream': True
        }

    elif config.provider == 'Google Gemini':
        return {
            'contents': [{'parts': [{'text': prompt}]}],
            'generationConfig': {
                'maxOutputTokens': 256
            }
        }

    return {}


def make_streaming_request(
    config: APIConfig,
    prompt: str,
    iteration: int
) -> RequestResult:
    """Make a streaming API request and measure performance with accurate TTFT"""

    payload = build_payload(config, prompt)
    start_time = time.time()
    ttft = 0.0
    response_text = ""

    try:
        # Parse URL
        parsed = urlparse(config.endpoint)
        host = parsed.netloc or parsed.hostname or 'api.anthropic.com'
        port = parsed.port or (443 if parsed.scheme == 'https' else 80)
        path = parsed.path or '/'

        # Add query string if present
        if parsed.query:
            path = f"{path}?{parsed.query}"

        # Prepare request body
        body = json.dumps(payload).encode('utf-8')

        # Create connection
        is_https = parsed.scheme == 'https' or host.endswith('.com')
        if is_https:
            conn = http.client.HTTPSConnection(host, port, timeout=120)
        else:
            conn = http.client.HTTPConnection(host, port, timeout=120)

        # Build headers
        headers = dict(config.headers)
        headers['Content-Length'] = str(len(body))
        if is_https or not parsed.port:
            # Standard headers for HTTPS
            pass

        # Send request
        conn.request('POST', path, body, headers)

        # Get response with streaming
        response = conn.getresponse()

        if response.status != 200:
            error_text = response.read().decode('utf-8', errors='ignore')
            conn.close()
            return RequestResult(
                iteration=iteration,
                success=False,
                response_time=time.time() - start_time,
                ttft=0,
                tokens=0,
                tps=0,
                error=f"HTTP {response.status}: {error_text[:200]}"
            )

        # Read streaming response chunk by chunk
        first_token_received = False
        chunk_size = 1024

        while True:
            chunk = response.read(chunk_size)
            if not chunk:
                break

            # Record time to first token
            if not first_token_received:
                ttft = time.time() - start_time
                first_token_received = True

            # Decode and accumulate
            text = chunk.decode('utf-8', errors='ignore')
            response_text += text

            # Check for end of stream
            if '[DONE]' in response_text or '</s>' in response_text:
                break

        conn.close()

        # Calculate metrics
        response_time = time.time() - start_time
        tokens = count_tokens(response_text, config.provider)
        tokens = max(tokens, 1)  # At least 1 token

        return RequestResult(
            iteration=iteration,
            success=True,
            response_time=response_time,
            ttft=ttft,
            tokens=tokens,
            tps=tokens / response_time if response_time > 0 else 0
        )

    except socket.timeout:
        return RequestResult(
            iteration=iteration,
            success=False,
            response_time=time.time() - start_time,
            ttft=0,
            tokens=0,
            tps=0,
            error="Request timeout"
        )
    except Exception as e:
        return RequestResult(
            iteration=iteration,
            success=False,
            response_time=time.time() - start_time,
            ttft=0,
            tokens=0,
            tps=0,
            error=str(e)
        )


def count_tokens(text: str, provider: str) -> int:
    """Count tokens from streaming response text"""
    tokens = 0

    if provider == 'Anthropic':
        # Parse SSE lines
        for line in text.split('\n'):
            line = line.strip()
            if line.startswith('data:'):
                data_str = line[5:].strip()
                if data_str and data_str != '[DONE]':
                    try:
                        data = json.loads(data_str)
                        if 'delta' in data:
                            delta = data['delta']
                            if 'text' in delta:
                                tokens += count_words(delta['text'])
                            elif 'type' in delta and delta['type'] == 'content_block_stop':
                                pass
                    except:
                        pass

    elif provider in ('OpenAI', 'Azure OpenAI'):
        # Parse SSE lines
        for line in text.split('\n'):
            line = line.strip()
            if line.startswith('data:'):
                data_str = line[5:].strip()
                if data_str and data_str != '[DONE]':
                    try:
                        data = json.loads(data_str)
                        if 'choices' in data and len(data['choices']) > 0:
                            delta = data['choices'][0].get('delta', {})
                            if 'content' in delta:
                                tokens += count_words(delta['content'])
                    except:
                        pass

    else:
        # Fallback: estimate by words
        tokens = count_words(text)

    return tokens


def count_words(text: str) -> int:
    """Simple word count (approximate token count)"""
    # Basic estimation: ~0.75 tokens per word for English
    words = len(text.split())
    return max(int(words * 1.3), words)  # Slightly overestimate


def run_benchmark(
    config: APIConfig,
    iterations: int,
    prompt: str
) -> list[RequestResult]:
    """Run benchmark with specified iterations"""

    results = []

    for i in range(iterations):
        print(f"  Running iteration {i+1}/{iterations}...")
        result = make_streaming_request(config, prompt, i + 1)
        results.append(result)

        # Small delay between requests
        if i < iterations - 1:
            time.sleep(0.5)

    return results


def calculate_percentile(data: list[float], percentile: float) -> float:
    """Calculate percentile from sorted data"""
    if not data:
        return 0.0
    sorted_data = sorted(data)
    index = int(len(sorted_data) * percentile / 100)
    return sorted_data[min(index, len(sorted_data) - 1)]


def generate_report(
    config: APIConfig,
    results: list[RequestResult],
    prompt: str,
    iterations: int
) -> BenchmarkReport:
    """Generate benchmark report from results"""

    successful = [r for r in results if r.success]
    failed = [r for r in results if not r.success]

    if not successful:
        return BenchmarkReport(
            timestamp=datetime.now().isoformat(),
            provider=config.provider,
            endpoint=config.endpoint,
            model=config.model,
            prompt=prompt,
            iterations=iterations,
            avg_response_time=0,
            min_response_time=0,
            max_response_time=0,
            p50_response_time=0,
            p95_response_time=0,
            p99_response_time=0,
            avg_ttft=0,
            min_ttft=0,
            max_ttft=0,
            avg_tps=0,
            min_tps=0,
            max_tps=0,
            total_tokens=0,
            success_count=0,
            failure_count=len(failed),
            results=[asdict(r) for r in results]
        )

    response_times = [r.response_time for r in successful]
    ttfts = [r.ttft for r in successful if r.ttft > 0]
    tps_values = [r.tps for r in successful]

    return BenchmarkReport(
        timestamp=datetime.now().isoformat(),
        provider=config.provider,
        endpoint=config.endpoint,
        model=config.model,
        prompt=prompt,
        iterations=iterations,
        avg_response_time=statistics.mean(response_times),
        min_response_time=min(response_times),
        max_response_time=max(response_times),
        p50_response_time=calculate_percentile(response_times, 50),
        p95_response_time=calculate_percentile(response_times, 95),
        p99_response_time=calculate_percentile(response_times, 99),
        avg_ttft=statistics.mean(ttfts) if ttfts else 0,
        min_ttft=min(ttfts) if ttfts else 0,
        max_ttft=max(ttfts) if ttfts else 0,
        avg_tps=statistics.mean(tps_values),
        min_tps=min(tps_values),
        max_tps=max(tps_values),
        total_tokens=sum(r.tokens for r in successful),
        success_count=len(successful),
        failure_count=len(failed),
        results=[asdict(r) for r in results]
    )


def format_markdown_report(report: BenchmarkReport) -> str:
    """Format benchmark report as Markdown"""

    lines = [
        "# LLM API Benchmark Report",
        "",
        "## Test Information",
        f"- **Time**: {report.timestamp}",
        f"- **Provider**: {report.provider}",
        f"- **Endpoint**: {report.endpoint}",
        f"- **Model**: {report.model}",
        f"- **Prompt**: {report.prompt}",
        f"- **Iterations**: {report.iterations}",
        "",
    ]

    if report.failure_count > 0:
        lines.extend([
            "## Errors",
            f"- **Success**: {report.success_count} | **Failed**: {report.failure_count}",
            "",
        ])

        for r in report.results:
            if not r['success']:
                lines.append(f"- Iteration {r['iteration']}: {r['error']}")
        lines.append("")

    lines.extend([
        "## Performance Metrics",
        "",
        "### Response Time (seconds)",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Average | {report.avg_response_time:.3f}s |",
        f"| Minimum | {report.min_response_time:.3f}s |",
        f"| Maximum | {report.max_response_time:.3f}s |",
        f"| P50 | {report.p50_response_time:.3f}s |",
        f"| P95 | {report.p95_response_time:.3f}s |",
        f"| P99 | {report.p99_response_time:.3f}s |",
        "",
        "### Time to First Token (TTFT)",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Average | {report.avg_ttft:.3f}s |",
        f"| Minimum | {report.min_ttft:.3f}s |",
        f"| Maximum | {report.max_ttft:.3f}s |",
        "",
        "### Tokens Per Second (TPS)",
        "| Metric | Value |",
        "|--------|-------|",
        f"| Average | {report.avg_tps:.2f} |",
        f"| Minimum | {report.min_tps:.2f} |",
        f"| Maximum | {report.max_tps:.2f} |",
        "",
        f"**Total Tokens**: {report.total_tokens}",
        "",
        "## Detailed Results",
        "",
        "| # | Response Time | TTFT | Tokens | TPS | Status |",
        "|---|---------------|------|--------|-----|--------|",
    ])

    for r in report.results:
        status = "OK" if r['success'] else "FAIL"
        if r['success']:
            lines.append(
                f"| {r['iteration']} | {r['response_time']:.3f}s | "
                f"{r['ttft']:.3f}s | {r['tokens']} | {r['tps']:.2f} | {status} |"
            )
        else:
            lines.append(f"| {r['iteration']} | - | - | - | - | {status} |")

    return "\n".join(lines)


def list_presets():
    """List available preset prompts"""
    print("Available presets:")
    print("-" * 50)
    for key, info in PRESET_PROMPTS.items():
        print(f"  {key:12} - {info['name']}")
        print(f"               {info['description']}")
        print()


def main():
    parser = argparse.ArgumentParser(
        description="LLM API Benchmark Tool - Auto-detect and test current LLM endpoint",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python benchmark.py                          # Run with default (code preset)
  python benchmark.py --preset throughput      # Use throughput preset for TPS testing
  python benchmark.py --preset quick -i 3      # Quick test with 3 iterations
  python benchmark.py -p "Your custom prompt"  # Custom prompt

Available presets:
  quick      - Short prompt for fast testing
  standard   - Medium prompt (counting test)
  long       - Longer output test
  throughput - High token output for TPS testing
  code       - Code generation test (default, ~500-1000 tokens)
  json       - JSON output test
        """
    )
    parser.add_argument(
        '--iterations', '-i',
        type=int,
        default=5,
        help='Number of benchmark iterations (default: 5)'
    )
    parser.add_argument(
        '--model', '-m',
        help='Override model name'
    )
    parser.add_argument(
        '--prompt', '-p',
        help='Custom prompt to send'
    )
    parser.add_argument(
        '--preset',
        choices=list(PRESET_PROMPTS.keys()),
        help='Use a preset prompt'
    )
    parser.add_argument(
        '--list-presets',
        action='store_true',
        help='List available presets and exit'
    )
    parser.add_argument(
        '--output-dir', '-o',
        default='reports',
        help='Output directory for reports (default: reports)'
    )
    parser.add_argument(
        '--quiet', '-q',
        action='store_true',
        help='Suppress progress output'
    )

    args = parser.parse_args()

    if args.list_presets:
        list_presets()
        return

    # Determine prompt to use
    if args.preset:
        prompt = PRESET_PROMPTS[args.preset]['prompt']
        if not args.quiet:
            print(f"Using preset: {PRESET_PROMPTS[args.preset]['name']}")
    elif args.prompt:
        prompt = args.prompt
    else:
        # Default to code preset (optimized for coding workflows)
        prompt = PRESET_PROMPTS['code']['prompt']

    if not args.quiet:
        print("=" * 60)
        print("LLM API Benchmark Tool")
        print("=" * 60)

    # Detect API configuration
    if not args.quiet:
        print("\nDetecting API configuration from environment...")
    config = detect_api_config()

    if not config:
        print("\nError: No LLM API detected from environment variables.")
        print("Supported providers:")
        print("  - ANTHROPIC_API_KEY / ANTHROPIC_AUTH_TOKEN (Anthropic/Claude)")
        print("  - OPENAI_API_KEY (OpenAI)")
        print("  - AZURE_OPENAI_API_KEY (Azure OpenAI)")
        print("  - GOOGLE_GENERATIVE_AI_API_KEY (Google Gemini)")
        print("  - AWS_ACCESS_KEY_ID (AWS Bedrock)")
        sys.exit(1)

    # Override model if specified
    if args.model:
        config.model = args.model

    if not args.quiet:
        print(f"  Detected: {config.provider}")
        print(f"  Endpoint: {config.endpoint}")
        print(f"  Model: {config.model}")
        print(f"\nRunning benchmark ({args.iterations} iterations)...")

    # Run benchmark
    results = run_benchmark(config, args.iterations, prompt)

    # Generate report
    if not args.quiet:
        print("\nGenerating report...")
    report = generate_report(config, results, prompt, args.iterations)

    # Save report
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    output_dir = Path(args.output_dir) / f"llm-benchmark-{timestamp}"
    output_dir.mkdir(parents=True, exist_ok=True)

    report_path = output_dir / "benchmark-report.md"
    report_path.write_text(format_markdown_report(report), encoding='utf-8')

    # Also save JSON for programmatic access
    json_path = output_dir / "benchmark-data.json"
    json_path.write_text(json.dumps(asdict(report), indent=2), encoding='utf-8')

    # Print summary
    if not args.quiet:
        print("\n" + "=" * 60)
        print("Benchmark Complete!")
        print("=" * 60)

    if report.success_count > 0:
        print(f"\nResponse Time: {report.avg_response_time:.3f}s (avg)")
        print(f"TTFT: {report.avg_ttft:.3f}s (avg)")
        print(f"TPS: {report.avg_tps:.2f} (avg)")
        print(f"\nSuccess: {report.success_count} | Failed: {report.failure_count}")
    else:
        print(f"\nAll requests failed! Check errors below:")

    print(f"\nReport saved to: {report_path}")

    # Print errors if any
    if report.failure_count > 0:
        print("\nErrors:")
        for r in results:
            if not r.success:
                print(f"  Iteration {r.iteration}: {r.error}")


if __name__ == "__main__":
    main()