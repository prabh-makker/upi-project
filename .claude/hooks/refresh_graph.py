"""
SessionStart hook: rebuilds the project graph with Graphify and shows its report to Claude,
so every new, resumed or compacted Claude session starts with a map of the code, SQL and docs.

- Code-only rebuild: no AI calls, no API key, about 1 second
- First run installs Graphify (pip package graphifyy, with SQL support)
- Never blocks the session: if Graphify can't be installed or run, it says so and exits normally

Output: graphify-out/ (graph.json, graph.html to open in a browser, GRAPH_REPORT.md), not committed.
"""

import importlib.util
import os
import subprocess
import sys

root = os.environ.get('CLAUDE_PROJECT_DIR') or os.getcwd()
report = os.path.join(root, 'graphify-out', 'GRAPH_REPORT.md')
sys.stdout.reconfigure(encoding='utf-8')  # the report has symbols a Windows console code page can't print

try:
    # A plain "pip install graphifyy" (what /graphify runs) has no SQL grammar, so check for both
    if importlib.util.find_spec('graphify') is None or importlib.util.find_spec('tree_sitter_sql') is None:
        subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', 'graphifyy[sql]'],
                       capture_output=True, timeout=300)
    # --force: rebuild from the current files even if the graph shrank (code was deleted)
    subprocess.run([sys.executable, '-m', 'graphify', 'update', '.', '--force'],
                   cwd=root, capture_output=True, timeout=120)
except (OSError, subprocess.TimeoutExpired) as e:
    print(f"Graphify refresh skipped: {e}")

if os.path.exists(report):
    print("Project map from Graphify, rebuilt at session start (graphify-out/GRAPH_REPORT.md).\n"
          "For details: python -m graphify query \"<question>\" | path \"A\" \"B\" | explain \"X\"\n")
    with open(report, encoding='utf-8') as f:
        print(f.read())
else:
    print("Graphify graph not available this session (install or rebuild failed). Type /graphify to build it.")
