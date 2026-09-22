FROM python:3.12-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    NEMOGUARDRAILS_LLM_FRAMEWORK=langchain

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Make startup script executable
RUN chmod +x run.sh

# Expose ports: 8501 (Streamlit Frontend) and 8000 (FastAPI Backend)
EXPOSE 8501 8000

CMD ["./run.sh"]
