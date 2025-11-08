FROM python:3.11-slim

WORKDIR /app

# Install system dependencies required for Pillow, Torch vision ops, curl for healthchecks
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    libjpeg-dev \
    zlib1g-dev \
    libpng-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt \
    && pip install --no-cache-dir gunicorn

# Copy application code
COPY . .

# Create non-root user
RUN useradd --create-home --shell /bin/bash app \
    && chown -R app:app /app
USER app

# Expose port
EXPOSE 5000

# Environment defaults (override in runtime or compose)
ENV PORT=5000 \
    FLASK_DEBUG=False

# Health check uses /warmup for deeper readiness
HEALTHCHECK --interval=30s --timeout=30s --start-period=25s --retries=3 \
    CMD curl -f http://localhost:${PORT}/warmup || exit 1

# Gunicorn for production (3 workers, preload for faster model warm)
# app:app refers to Flask instance 'app' in app.py
CMD ["gunicorn", "--workers", "3", "--timeout", "180", "--bind", "0.0.0.0:5000", "app:app", "--preload"]