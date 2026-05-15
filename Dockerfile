# ─── Stage 1: Install Python deps ────────────────────────────────────────────
FROM python:3.11-slim AS python-deps

WORKDIR /app

# Install system libraries required by OpenCV + scikit-image
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt


# ─── Stage 2: Build Next.js ──────────────────────────────────────────────────
FROM node:20-slim AS nextjs-builder

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build


# ─── Stage 3: Final runtime image ────────────────────────────────────────────
FROM node:20-slim AS runner

WORKDIR /app

# Install Python 3 + runtime system libs
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-distutils \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/*

# Copy installed Python packages from python-deps stage
COPY --from=python-deps /usr/local/lib/python3.11 /usr/local/lib/python3.11
COPY --from=python-deps /usr/local/bin/python3.11 /usr/local/bin/python3.11
RUN ln -sf /usr/local/bin/python3.11 /usr/local/bin/python3 \
    && ln -sf /usr/local/bin/python3.11 /usr/local/bin/python

# Copy built Next.js app
COPY --from=nextjs-builder /app/.next ./.next
COPY --from=nextjs-builder /app/node_modules ./node_modules
COPY --from=nextjs-builder /app/public ./public
COPY --from=nextjs-builder /app/package.json ./package.json
COPY --from=nextjs-builder /app/next.config.mjs ./next.config.mjs

# Copy model files, inference scripts, and config
COPY scripts/ ./scripts/
COPY Direct_Models/ ./Direct_Models/
COPY models/ ./models/

# Environment
ENV NODE_ENV=production
ENV PYTHON_BIN=python3

# Render injects PORT=10000 at runtime; expose it
EXPOSE 10000

CMD ["sh", "-c", "node_modules/.bin/next start -p ${PORT:-3000}"]
