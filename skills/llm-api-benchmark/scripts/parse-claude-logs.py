#!/usr/bin/env python3
"""
Parse Claude Code debug logs to extract precise timing information

This script analyzes Claude Code debug logs to extract:
- Request start time
- Time to first token (TTFT)
- Total response time
- Token usage statistics

Usage:
    python parse-claude-logs.py --session-start 2026-03-02T10:00:00
    python parse-claude-logs.py --last-minutes 5
    python parse-claude-logs.py --file ~/.claude/logs/claude-2026-03-02.log
"""

import argparse
import json
import glob
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Optional
from dataclasses import dataclass, asdict
from collections import defaultdict


@dataclass
class RequestMetrics:
    """Metrics for a single LLM request"""
    request_id: str
    start_time: datetime
    first_token_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    model: str = "unknown"
    input_tokens: int = 0
    output_tokens: int = 0

    @property
    def ttft(self) -> Optional[float]:
        """Time to first token in seconds"""
        if self.first_token_time and self.start_time:
            return (self.first_token_time - self.start_time).total_seconds()
        return None

    @property
    def total_time(self) -> Optional[float]:
        """Total request time in seconds"""
        if self.end_time and self.start_time:
            return (self.end_time - self.start_time).total_seconds()
        return None

    @property
    def tps(self) -> Optional[float]:
        """Tokens per second"""
        if self.output_tokens > 0 and self.total_time and self.total_time > 0:
            return self.output_tokens / self.total_time
        return None


def find_log_files(log_dir: str = "~/.claude/logs", since: Optional[datetime] = None) -> list[Path]:
    """Find Claude log files"""
    log_path = Path(log_dir).expanduser()

    if not log_path.exists():
        return []

    # Look for log files
    patterns = [
        "claude-*.log",
        "*.log"
    ]

    files = []
    for pattern in patterns:
        files.extend(log_path.glob(pattern))

    # Filter by time if specified
    if since:
        files = [
            f for f in files
            if datetime.fromtimestamp(f.stat().st_mtime) >= since
        ]

    return sorted(files, key=lambda f: f.stat().st_mtime, reverse=True)


def parse_log_line(line: str) -> Optional[dict]:
    """Parse a single log line"""
    try:
        # Try JSON format first
        return json.loads(line)
    except json.JSONDecodeError:
        pass

    # Try to parse common log formats
    # Example: 2026-03-02T10:30:00.123Z [DEBUG] Message
    patterns = [
        r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z?)\s+\[(\w+)\]\s+(.*)$',
        r'^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+\[(\w+)\]\s+(.*)$',
    ]

    for pattern in patterns:
        match = re.match(pattern, line.strip())
        if match:
            timestamp_str, level, message = match.groups()
            try:
                # Parse timestamp
                timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                return {
                    'timestamp': timestamp.isoformat(),
                    'level': level,
                    'message': message
                }
            except ValueError:
                continue

    return None


def extract_requests(log_files: list[Path], session_start: Optional[datetime] = None) -> dict[str, RequestMetrics]:
    """Extract request metrics from log files"""
    requests: dict[str, RequestMetrics] = {}

    for log_file in log_files:
        try:
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    entry = parse_log_line(line)
                    if not entry:
                        continue

                    timestamp_str = entry.get('timestamp')
                    if not timestamp_str:
                        continue

                    try:
                        timestamp = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
                    except ValueError:
                        continue

                    # Filter by session start
                    if session_start and timestamp < session_start:
                        continue

                    message = entry.get('message', '')
                    level = entry.get('level', '').upper()

                    # Look for request start
                    if 'API request' in message or 'sending request' in message.lower():
                        # Extract request ID if available
                        req_id = extract_request_id(message) or f"req_{timestamp.isoformat()}"
                        if req_id not in requests:
                            requests[req_id] = RequestMetrics(
                                request_id=req_id,
                                start_time=timestamp
                            )

                    # Look for first token / streaming start
                    elif 'streaming' in message.lower() or 'first chunk' in message.lower():
                        req_id = extract_request_id(message)
                        if req_id and req_id in requests:
                            requests[req_id].first_token_time = timestamp

                    # Look for request completion
                    elif 'response received' in message.lower() or 'request complete' in message.lower():
                        req_id = extract_request_id(message)
                        if req_id and req_id in requests:
                            requests[req_id].end_time = timestamp

                    # Look for token usage
                    elif 'usage' in message.lower() or 'tokens' in message.lower():
                        req_id = extract_request_id(message)
                        if req_id and req_id in requests:
                            tokens = extract_tokens(message)
                            if tokens:
                                requests[req_id].input_tokens = tokens.get('input', 0)
                                requests[req_id].output_tokens = tokens.get('output', 0)

                    # Look for model info
                    elif 'model' in message.lower():
                        req_id = extract_request_id(message)
                        if req_id and req_id in requests:
                            model = extract_model(message)
                            if model:
                                requests[req_id].model = model

        except Exception as e:
            print(f"Warning: Error reading {log_file}: {e}", file=sys.stderr)
            continue

    return requests


def extract_request_id(message: str) -> Optional[str]:
    """Extract request ID from log message"""
    patterns = [
        r'request[_-]?id["\']?\s*[:=]\s*["\']?([a-zA-Z0-9_-]+)',
        r'["\']?id["\']?\s*[:=]\s*["\']?([a-zA-Z0-9_-]+)',
    ]

    for pattern in patterns:
        match = re.search(pattern, message, re.IGNORECASE)
        if match:
            return match.group(1)

    return None


def extract_tokens(message: str) -> Optional[dict]:
    """Extract token counts from log message"""
    tokens = {}

    # Look for input tokens
    input_match = re.search(r'input[_-]?tokens?[\s"\']*[:=]\s*(\d+)', message, re.IGNORECASE)
    if input_match:
        tokens['input'] = int(input_match.group(1))

    # Look for output tokens
    output_match = re.search(r'output[_-]?tokens?[\s"\']*[:=]\s*(\d+)', message, re.IGNORECASE)
    if output_match:
        tokens['output'] = int(output_match.group(1))

    return tokens if tokens else None


def extract_model(message: str) -> Optional[str]:
    """Extract model name from log message"""
    patterns = [
        r'model["\']?\s*[:=]\s*["\']?([a-zA-Z0-9_.-]+)',
    ]

    for pattern in patterns:
        match = re.search(pattern, message, re.IGNORECASE)
        if match:
            return match.group(1)

    return None


def format_report(requests: dict[str, RequestMetrics]) -> str:
    """Format metrics as a report"""
    if not requests:
        return "No requests found in logs."

    lines = [
        "# Claude Log Analysis Report",
        "",
        f"Total Requests: {len(requests)}",
        "",
        "## Request Details",
        "",
        "| Request ID | Model | Total Time | TTFT | Output Tokens | TPS |",
        "|------------|-------|------------|------|---------------|-----|",
    ]

    for req in requests.values():
        total_time = f"{req.total_time:.3f}s" if req.total_time else "N/A"
        ttft = f"{req.ttft:.3f}s" if req.ttft else "N/A"
        tps = f"{req.tps:.2f}" if req.tps else "N/A"

        lines.append(
            f"| {req.request_id[:20]}... | {req.model} | {total_time} | {ttft} | {req.output_tokens} | {tps} |"
        )

    # Statistics
    completed = [r for r in requests.values() if r.total_time is not None]
    if completed:
        lines.extend([
            "",
            "## Statistics",
            "",
            f"- **Completed Requests**: {len(completed)}/{len(requests)}",
            f"- **Average Total Time**: {sum(r.total_time for r in completed)/len(completed):.3f}s",
        ])

        with_ttft = [r for r in completed if r.ttft is not None]
        if with_ttft:
            lines.append(f"- **Average TTFT**: {sum(r.ttft for r in with_ttft)/len(with_ttft):.3f}s")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Parse Claude Code debug logs for performance metrics"
    )
    parser.add_argument(
        "--file", "-f",
        help="Specific log file to parse"
    )
    parser.add_argument(
        "--log-dir",
        default="~/.claude/logs",
        help="Log directory (default: ~/.claude/logs)"
    )
    parser.add_argument(
        "--session-start",
        help="Session start time (ISO format)"
    )
    parser.add_argument(
        "--last-minutes", "-m",
        type=int,
        help="Parse logs from last N minutes"
    )
    parser.add_argument(
        "--output", "-o",
        help="Output file for JSON results"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output as JSON"
    )

    args = parser.parse_args()

    # Determine time filter
    session_start = None
    if args.session_start:
        session_start = datetime.fromisoformat(args.session_start.replace('Z', '+00:00'))
    elif args.last_minutes:
        session_start = datetime.now() - timedelta(minutes=args.last_minutes)

    # Find log files
    if args.file:
        log_files = [Path(args.file)]
    else:
        log_files = find_log_files(args.log_dir, session_start)

    if not log_files:
        print("No log files found.", file=sys.stderr)
        print(f"Log directory: {Path(args.log_dir).expanduser()}", file=sys.stderr)
        return 1

    # Extract requests
    requests = extract_requests(log_files, session_start)

    if not requests:
        print("No requests found in logs.")
        return 0

    # Output
    if args.json or args.output:
        data = {
            "total_requests": len(requests),
            "requests": [asdict(r) for r in requests.values()]
        }
        json_output = json.dumps(data, indent=2, default=str)

        if args.output:
            Path(args.output).write_text(json_output)
            print(f"Results saved to {args.output}")
        else:
            print(json_output)
    else:
        print(format_report(requests))

    return 0


if __name__ == "__main__":
    sys.exit(main())
