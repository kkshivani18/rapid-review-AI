FROM python:3.12-slim

WORKDIR /app

# Install system dependencies needed for stripping binaries and cleaning up
RUN apt-get update && apt-get install -y --no-install-recommends \
    binutils \
    && rm -rf /var/lib/apt/lists/*

# 1. Install CPU-only torch first to prevent default CUDA bloat (~4.5GB savings)
RUN pip install --no-cache-dir --timeout 600 torch --index-url https://download.pytorch.org/whl/cpu

# 2. Copy and install rest of requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 3. Pre-download embedding model at build time so ECS tasks boot instantly
# Storing it in a dedicated cache directory
ENV HF_HOME=/app/models
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')"

# 4. Bulletproof site-packages cleanup (safe for boto3 and sentence-transformers)
RUN find /usr/local/lib/python3.12/site-packages -type d \( \
        -name "test" -o -name "tests" -o -name "__pycache__" -o \
        -name "benchmark" -o -name "scripts" -o -name "examples" \
    \) -exec rm -rf {} + 2>/dev/null || true && \
    find /usr/local/lib/python3.12/site-packages -name "*.pyc" -delete && \
    find /usr/local/lib/python3.12/site-packages -name "*.so" -exec strip --strip-debug {} + 2>/dev/null || true && \
    rm -rf /root/.cache/pip /tmp/* /var/tmp/*

# Copy application files
COPY app/ ./app/

# Expose port for documentation clarity
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]