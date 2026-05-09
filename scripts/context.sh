#!/bin/bash
# Quick context snapshot for AI session warm-start.
# Usage: ./scripts/context.sh
# Output: Markdown-formatted project context suitable for pasting into AI chat.

set -euo pipefail
cd "$(dirname "$0")/.."

python3 scripts/context_snapshot.py | python3 -c "
import json, sys

data = json.load(sys.stdin)

print('## Project Context Snapshot')
print()
print(f'**Branch:** \`{data[\"branch\"]}\`')
print()

print('### Recent Commits')
for c in data['recent_commits']:
    print(f'- {c}')
print()

print('### Current Phase')
print(data['tasks_phase'])
print()

print('### Spec Metadata')
for s in data['spec_metadata']:
    name = s['path'].split('/')[-2] if '/specs/' in s['path'] else s['path']
    print(f'- \`{name}\`: hardware_required={s[\"hardware_required\"]}, depends_on={s[\"depends_on\"]}')
print()

if data['recently_changed_files']:
    print('### Recently Changed (7d)')
    files = data['recently_changed_files']
    for f in files[:12]:
        print(f'- \`{f}\`')
    if len(files) > 12:
        print(f'- ... {len(files) - 12} more')

if data.get('worktree_changes'):
    print()
    print('### Working Tree Changes')
    changes = data['worktree_changes']
    for f in changes[:12]:
        print(f'- \`{f}\`')
    if len(changes) > 12:
        print(f'- ... {len(changes) - 12} more')
"
