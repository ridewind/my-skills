#!/usr/bin/env python3
"""
Compare benchmark results across endpoints

Usage:
    python compare-results.py
    python compare-results.py --dir ./my-reports
    python compare-results.py --format json
"""

import argparse
import json
import glob
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional


def load_results(results_dir: Path) -> list[dict]:
    """Load all benchmark results from directory"""
    results = []

    if not results_dir.exists():
        return results

    for file_path in results_dir.glob("*.json"):
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
                # Add file metadata
                data['_source_file'] = file_path.name
                data['_modified'] = datetime.fromtimestamp(
                    file_path.stat().st_mtime
                ).isoformat()
                results.append(data)
        except Exception as e:
            print(f"Warning: Failed to load {file_path}: {e}", file=sys.stderr)
            continue

    return results


def format_endpoint_name(endpoint: str) -> str:
    """Format endpoint name for display"""
    # Remove protocol
    name = endpoint.replace("https://", "").replace("http://", "")
    # Replace special chars
    name = name.replace("/", "_").replace(":", "_")
    # Truncate
    if len(name) > 35:
        name = name[:32] + "..."
    return name


def generate_comparison(results: list[dict], output_format: str = "table") -> str:
    """Generate comparison report"""

    if len(results) < 1:
        return "No benchmark results found."

    # Group by endpoint, keeping the most recent for each
    endpoint_results = {}
    for r in results:
        ep = r.get("endpoint", "unknown")
        if ep not in endpoint_results:
            endpoint_results[ep] = r
        else:
            # Keep the more recent one
            if r.get("timestamp", "") > endpoint_results[ep].get("timestamp", ""):
                endpoint_results[ep] = r

    # Convert back to list and sort by avg_time
    unique_results = sorted(
        endpoint_results.values(),
        key=lambda x: x.get("avg_time", float('inf'))
    )

    if output_format == "json":
        return json.dumps({
            "comparison_date": datetime.now().isoformat(),
            "endpoints_tested": len(unique_results),
            "results": unique_results
        }, indent=2)

    # Table format
    lines = [
        "",
        "=" * 85,
        "                    LLM API ENDPOINT COMPARISON",
        "=" * 85,
        "",
        f"{'Endpoint':<38} {'Avg':<10} {'Min':<10} {'Max':<10} {'Relative':<12}",
        "-" * 85,
    ]

    if not unique_results:
        lines.append("No results to display.")
        return "\n".join(lines)

    baseline_time = unique_results[0].get("avg_time", 1)

    for r in unique_results:
        endpoint = format_endpoint_name(r.get("endpoint", "unknown"))
        avg = r.get("avg_time", 0)
        min_t = r.get("min_time", 0)
        max_t = r.get("max_time", 0)

        avg_str = f"{avg:.2f}s"
        min_str = f"{min_t:.2f}s"
        max_str = f"{max_t:.2f}s"

        # Calculate relative speed
        if avg > 0:
            ratio = baseline_time / avg
            if ratio >= 0.95:
                relative = "⚡ baseline"
            else:
                speedup = 1 / ratio
                relative = f"{speedup:.1f}× slower"
        else:
            relative = "N/A"

        lines.append(
            f"{endpoint:<38} {avg_str:<10} {min_str:<10} {max_str:<10} {relative:<12}"
        )

    lines.extend([
        "-" * 85,
        f"Total endpoints tested: {len(unique_results)}",
        "",
        "Notes:",
        "  - 'Avg' is the average response time across all iterations",
        "  - Relative speed compares each endpoint to the fastest (baseline)",
        "",
    ])

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Compare LLM benchmark results across endpoints"
    )
    parser.add_argument(
        "--dir", "-d",
        default="reports/llm-benchmark-subagent",
        help="Results directory (default: reports/llm-benchmark-subagent)"
    )
    parser.add_argument(
        "--format", "-f",
        choices=["table", "json"],
        default="table",
        help="Output format (default: table)"
    )
    parser.add_argument(
        "--output", "-o",
        help="Output file (default: print to stdout)"
    )

    args = parser.parse_args()

    results_dir = Path(args.dir)
    results = load_results(results_dir)

    if not results:
        print(f"No benchmark results found in: {results_dir}", file=sys.stderr)
        print("\nRun benchmarks first:", file=sys.stderr)
        print('  cc-switch <endpoint>', file=sys.stderr)
        print('  "测试当前端点性能"', file=sys.stderr)
        return 1

    report = generate_comparison(results, args.format)

    if args.output:
        Path(args.output).write_text(report)
        print(f"Report saved to: {args.output}")
    else:
        print(report)

    return 0


if __name__ == "__main__":
    sys.exit(main())
