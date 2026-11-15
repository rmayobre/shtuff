#!/usr/bin/env bash
# Regenerates docs/reference/*.md from the "# Function:" header comments in src/.
# Usage: ./docs/generate-reference.sh   (run from anywhere)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 - "$ROOT" <<'PY'
import glob, os, re, sys
root = sys.argv[1]
src = os.path.join(root, 'src')
out_dir = os.path.join(root, 'docs', 'reference')
os.makedirs(out_dir, exist_ok=True)

def files(*rel):
    return list(rel)

containers = sorted(os.path.relpath(p, src) for p in glob.glob(src + '/linux/containers/**/*.sh', recursive=True))
groups = {
 'logging': ('Logging', ['core/logging/log_bash.sh'],
   'info, warn, error, debug, verbose and log_output. Messages go to stderr. `LOG_LEVEL`, `LOG_FILE` and `LOG_TIMESTAMP` control output.'),
 'packaging': ('Package management', ['core/packaging/%s.sh' % n for n in ('install','update','uninstall','clean','dependencies')],
   'Detects apt, dnf, yum, zypper, pacman, apk and Homebrew automatically. Each call runs in the background behind a loading indicator.'),
 'monitor': ('Monitoring and utilities', ['core/utils/%s.sh' % n for n in ('monitor','stop','download','progress')],
   '`monitor` waits on a background PID and shows a loading indicator. Start the command with `&` and pass `$!`.'),
 'file-operations': ('File operations', ['core/utils/%s.sh' % n for n in ('copy','move','delete')],
   'Copy, move and delete with a progress indicator. Append `|| exit 1` to propagate failures.'),
 'prompts': ('Prompts', ['core/prompts/%s.sh' % n for n in ('question','options','selections','confirm')],
   'Interactive input. Results are stored in the global `$answer` (or the `$answers` array for `selections`).'),
 'networking': ('Networking', ['core/networking/scan.sh','core/networking/poll.sh','linux/networking/bridge.sh','linux/networking/forward.sh','linux/networking/network.sh'],
   '`scan` and `poll` are in core. `bridge`, `forward` and `network` are Linux-only (they need `ip` and `iptables`).'),
 'systemd': ('Systemd services and timers', ['linux/systemd/service.sh','linux/systemd/timer.sh'],
   'Linux only. Writes unit files and runs `systemctl`. OpenRC (Alpine) and launchd (macOS) equivalents are not implemented yet.'),
 'containers': ('Containers (LXC and Proxmox)', containers,
   'Linux only. LXC (`lxc_*`) and Proxmox CT (`pct_*`) functions plus shared helpers.'),
 'gpu': ('GPU', ['linux/gpu/gpu_list.sh','linux/gpu/gpu_select.sh','linux/gpu/gpu_install.sh'],
   'Linux only. Detect GPUs, pick one for a container and install drivers.'),
 'system': ('System', ['linux/system/locale.sh'], 'Linux only.'),
}
block = re.compile(r'((?:^#.*\n)+)', re.M)
for key, (title, fs, intro) in groups.items():
    out = ['# %s\n' % title, intro + '\n',
           '> Generated from the header comments in `src/` by `docs/generate-reference.sh`. Edit the headers, not this file.\n']
    for f in fs:
        text = open(os.path.join(src, f)).read()
        for m in block.finditer(text):
            h = m.group(1)
            nm = re.match(r'#\s*Function:\s*(\S+)', h)
            if not nm or nm.group(1).startswith('_'):
                continue
            body = '\n'.join(l[2:] if l.startswith('# ') else l[1:] for l in h.rstrip('\n').split('\n'))
            out.append('## `%s`\n\n_Source: `src/%s`_\n\n```text\n%s\n```\n' % (nm.group(1), f, body))
    open(os.path.join(out_dir, key + '.md'), 'w').write('\n'.join(out))
PY
