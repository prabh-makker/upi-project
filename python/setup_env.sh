#!/bin/bash
echo "=== UPI Project Setup ==="
python3 -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
echo "✓ Python environment ready"
jupyter notebook --version
echo "✓ Jupyter ready"
