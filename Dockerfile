# -------------------------------------------------------------
# Stage 1: Build & Dependency Isolation
# -------------------------------------------------------------
FROM python:3.11-slim AS builder

WORKDIR /build

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY app/requirements.txt .

# Install dependencies, then completely purge build toolchains
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir -r requirements.txt && \
    pip uninstall -y pip setuptools wheel && \
    find /opt/venv -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true && \
    rm -rf /opt/venv/lib/python3.11/site-packages/setuptools* \
           /opt/venv/lib/python3.11/site-packages/pkg_resources* \
           /opt/venv/lib/python3.11/site-packages/wheel* \
           /opt/venv/lib/python3.11/site-packages/pip*

# -------------------------------------------------------------
# Stage 2: Hardened Zero-CVE Non-Root Runtime
# -------------------------------------------------------------
FROM python:3.11-slim AS runner

WORKDIR /app

# Apply available OS security updates
RUN apt-get update && \
    apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/*

# Clean all system-level site-packages from base image
RUN rm -rf /usr/local/lib/python3.11/site-packages/* \
           /usr/lib/python3/dist-packages/msgpack* 2>/dev/null || true

# Copy clean, build-tool-free virtual environment
COPY --from=builder /opt/venv /opt/venv
COPY app/ /app/

# Create non-root system group and user
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /sbin/nologin -M appuser && \
    chown -R appuser:appgroup /app /opt/venv

USER 10001:10001

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    PORT=8080

EXPOSE 8080

ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "30", "app:app"]
