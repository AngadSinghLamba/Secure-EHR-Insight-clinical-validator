#!/bin/bash
set -e

echo "⏳ Starting FastAPI Backend Server on port 8000..."
uvicorn src.api.main:app --host 0.0.0.0 --port 8000 &

echo "⏳ Waiting for FastAPI to initialize..."
sleep 5

echo "🚀 Starting Streamlit Clinical Dashboard on port 8501..."
streamlit run src/ui/app.py --server.port 8501 --server.address 0.0.0.0
