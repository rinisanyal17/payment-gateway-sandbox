# -------------------------------------------------------------
# Stage 1: Build & Dependency Isolation
# -------------------------------------------------------------
FROM python:3.11-slim AS builder

WORKDIR /build

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY app/requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

# -------------------------------------------------------------
# Stage 2: Final Secure Non-Root Runtime
# -------------------------------------------------------------
FROM python:3.11-slim AS runner

WORKDIR /app

# Create non-root system group and user
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g appgroup -s /sbin/nologin -M appuser

# Copy installed Python packages from builder stage
COPY --from=builder /root/.local /home/appuser/.local
COPY app/ /app/

ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PORT=8080

RUN chown -R appuser:appgroup /app /home/appuser

USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "--timeout", "30", "app:app"]
