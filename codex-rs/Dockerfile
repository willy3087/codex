# Multi-stage Dockerfile for Codex Gateway
# Optimized for Google Cloud Run deployment
# Following best practices from working wrapper-cloud-run

# ============================================================================
# Stage 1: Builder - Compile Rust application
# ============================================================================
FROM rust:1.90-slim AS builder

# Install minimal build dependencies for compiling Rust with SSL support
RUN apt-get update && apt-get install -y --no-install-recommends \
    pkg-config \
    libssl-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory for the build
WORKDIR /build

# Copy workspace configuration files first for better caching
COPY Cargo.toml Cargo.lock ./

# Copy all workspace members in the correct sequence
# (matching the order in workspace Cargo.toml)
COPY backend-client ./backend-client/
COPY ansi-escape ./ansi-escape/
COPY async-utils ./async-utils/
COPY app-server ./app-server/
COPY app-server-protocol ./app-server-protocol/
COPY apply-patch ./apply-patch/
COPY arg0 ./arg0/
COPY feedback ./feedback/
COPY codex-backend-openapi-models ./codex-backend-openapi-models/
COPY cloud-tasks ./cloud-tasks/
COPY cloud-tasks-client ./cloud-tasks-client/
COPY cli ./cli/
COPY common ./common/
COPY core ./core/
COPY gateway ./gateway/
COPY exec ./exec/
COPY execpolicy ./execpolicy/
COPY keyring-store ./keyring-store/
COPY file-search ./file-search/
COPY linux-sandbox ./linux-sandbox/
COPY login ./login/
COPY mcp-server ./mcp-server/
COPY mcp-types ./mcp-types/
COPY ollama ./ollama/
COPY process-hardening ./process-hardening/
COPY protocol ./protocol/
COPY rmcp-client ./rmcp-client/
COPY responses-api-proxy ./responses-api-proxy/
COPY stdio-to-uds ./stdio-to-uds/
COPY otel ./otel/
COPY tui ./tui/
COPY utils ./utils/
COPY windows-sandbox-rs ./windows-sandbox-rs/
COPY chatgpt ./chatgpt/
COPY cloud-cli ./cloud-cli/
COPY code ./code/

# Copy additional configuration files
COPY rust-toolchain.toml ./
COPY rustfmt.toml ./
COPY clippy.toml ./

# Build the gateway in release mode with optimizations
RUN cargo build --release --package codex-gateway

# Strip debug symbols to reduce binary size
RUN strip target/release/codex-gateway

# ============================================================================
# Stage 2: Minimal runtime image
# ============================================================================
# Use debian:trixie-slim to match GLIBC version from rust:1.90-slim
FROM debian:trixie-slim

# Install runtime dependencies including Google Cloud SDK and Python 3
# (Python support for potential MCP servers integration)
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    curl \
    apt-transport-https \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-venv \
    && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list \
    && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
    && apt-get update && apt-get install -y --no-install-recommends google-cloud-cli \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user for security best practices
RUN useradd -m -u 1000 -s /bin/bash appuser

# Set working directory
WORKDIR /app

# Copy the compiled gateway binary from builder stage
COPY --from=builder /build/target/release/codex-gateway /app/codex-gateway

# Copy configuration file if it exists (optional)
# Note: Using shell to handle optional file copy
RUN echo "Configuration will be loaded from environment or defaults"

# Ensure binary is executable
RUN chmod +x /app/codex-gateway

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user for runtime
USER appuser

# Expose port 8080 (Cloud Run requirement)
EXPOSE 8080

# Set environment variables
ENV RUST_LOG=info
ENV PORT=8080

# Health check for container orchestrators
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Run the gateway server
ENTRYPOINT ["/app/codex-gateway"]
