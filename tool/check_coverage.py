#!/usr/bin/env python3
"""Parse coverage/lcov.info, print a per-area table, exit 1 below --min.

Usage: python3 tool/check_coverage.py --min 45
Run `flutter test --coverage test/` first.

ponytail: only counts files loaded by tests (flutter's lcov omits the rest);
add an import-all smoke test if untouched files should drag the number down.
"""

import argparse
import collections
import os
import sys


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--min', type=float, default=0.0)
    ap.add_argument('--lcov', default='coverage/lcov.info')
    args = ap.parse_args()

    files = {}
    cur = None
    for line in open(args.lcov):
        line = line.strip()
        if line.startswith('SF:'):
            path = line[3:]
            excluded = (
                path.endswith(('.g.dart', '.freezed.dart'))
                or '/l10n/' in path
                # design-system constants (colors, spacing, motion): no logic
                or path.startswith('lib/core/theme/')
            )
            cur = None if excluded else files.setdefault(path, [0, 0])
        elif line.startswith('DA:') and cur is not None:
            hits = int(line.split(',')[1])
            cur[1] += 1
            cur[0] += hits > 0

    areas = collections.defaultdict(lambda: [0, 0])
    for path, (h, t) in files.items():
        parts = path.replace('lib/', '', 1).split('/')
        key = '/'.join(parts[:2]) if parts[0] in ('features', 'core') else parts[0]
        areas[key][0] += h
        areas[key][1] += t

    hit = sum(h for h, _ in files.values())
    total = sum(t for _, t in files.values())
    pct = 100 * hit / total

    rows = ['| area | coverage | lines |', '|---|---|---|']
    for k, (h, t) in sorted(areas.items(), key=lambda kv: kv[1][0] / kv[1][1]):
        rows.append(f'| {k} | {100 * h / t:.1f}% | {h}/{t} |')
    rows.append(f'| **total** | **{pct:.1f}%** | **{hit}/{total}** |')
    report = '\n'.join(rows)
    print(report)

    step_summary = os.environ.get('GITHUB_STEP_SUMMARY')
    if step_summary:
        with open(step_summary, 'a') as f:
            f.write(f'## Test coverage\n\n{report}\n')

    if pct < args.min:
        sys.exit(f'coverage {pct:.1f}% is below the minimum {args.min}%')


main()
