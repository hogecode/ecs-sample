# ========================================
# Bastion Fargate - Alpine Linux Base
# ========================================

FROM alpine:latest

# Install required tools
RUN apk add --no-cache \
    aws-cli \
    openssh-client \
    postgresql-client \
    mysql-client \
    redis \
    curl \
    wget \
    git \
    jq \
    bash \
    ca-certificates \
    tini \
    openrc

# Create non-root user for SSM sessions
RUN addgroup -S ssm && adduser -S ssm-user -G ssm

# Copy entrypoint script
COPY bastion-fargate/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/entrypoint.sh"]

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD aws ec2-instance-connect ec2-instance-os-detect --help || exit 1
