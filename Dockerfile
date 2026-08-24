# -------------------------------------------------------------
# Stage 1: Build & Dependency Isolation
# -------------------------------------------------------------
FROM python:3.11-slim AS builder

WORKDIR /build

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY app/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# -------------------------------------------------------------
# Stage 2: Hardened Zero-CVE Non-Root Runtime
# -------------------------------------------------------------
FROM python:3.11-slim AS runner

WORKDIR /app

# Apply available OS security updates
RUN apt-get update && \
    apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/*

# Strip unneeded system build tools and metadata from the base image
RUN rm -rf /usr/local/lib/python3.11/site-packages/setuptools* \
           /usr/local/lib/python3.11/site-packages/wheel* \
           /usr/local/lib/python3.11/site-packages/pip* \
           /usr/local/lib/python3.11/site-packages/msgpack*

# Copy isolated virtual environment from builder stage
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
