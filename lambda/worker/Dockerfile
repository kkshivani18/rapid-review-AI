FROM public.ecr.aws/lambda/python:3.12

# Install CPU-only torch to avoid the 5GB CUDA bloat
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    find /var/lang/lib/python3.12/site-packages -type d \( \
        -name "test" -o -name "tests" -o -name "__pycache__" -o \
        -name "doc" -o -name "docs" -o -name "benchmark" -o \
        -name "datasets" -o -name "scripts" -o -name "examples" \
    \) -exec rm -rf {} + 2>/dev/null || true && \
    find /var/lang/lib/python3.12/site-packages -name "*.pyc" -delete && \
    find /var/lang/lib/python3.12/site-packages -name "*.so" -exec strip --strip-debug {} + 2>/dev/null || true && \
    rm -rf /root/.cache/pip /tmp/* /var/tmp/*

# Do NOT pre-download the model here. Model will be downloaded to /tmp at runtime.
# This keeps the image small enough for reliable Lambda initialization.

COPY handler.py ${LAMBDA_TASK_ROOT}

CMD ["handler.handler"]