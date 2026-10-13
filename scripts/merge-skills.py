#!/usr/bin/env python3
"""File-level skill merge used by macOS/Linux installer (stdlib only)."""
import hashlib, json, os, shutil, sys, uuid
from pathlib import Path
from datetime import datetime, timezone

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def merge(source, target, root, agent):
    source, target, root = map(Path, (source, target, root))
    key = agent + '-' + source.name
    ledger = root / '_skill-state' / (key + '.json')
    previous = json.loads(ledger.read_text('utf-8')) if ledger.exists() else {}
    legacy_path = root / 'scripts' / 'legacy-skill-hashes.json'
    legacy = json.loads(legacy_path.read_text('utf-8')) if legacy_path.exists() else {}
    next_state = {}
    for f in sorted(source.rglob('*')):
        if not f.is_file():
            continue
        rel = f.relative_to(source).as_posix()
        dst = target / rel
        sha = digest(f)
        if dst.exists():
            current = digest(dst)
            if current == sha:
                next_state[rel] = sha
                continue
            stamp = datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')
            backup = root / '_backup' / (key + '-' + stamp + '-' + uuid.uuid4().hex[:8]) / rel
            backup.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dst, backup)
            if previous.get(rel) != current and current.upper() not in legacy.get(source.name + '/' + rel, []):
                print('[冲突保留] ' + key + '/' + rel + '；已有内容已备份，未覆盖')
                if rel in previous:
                    next_state[rel] = previous[rel]
                continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, dst)
        next_state[rel] = sha
    ledger.parent.mkdir(parents=True, exist_ok=True)
    ledger.write_text(json.dumps(next_state, ensure_ascii=False, indent=2), 'utf-8')

if __name__ == '__main__':
    merge(*sys.argv[1:])
