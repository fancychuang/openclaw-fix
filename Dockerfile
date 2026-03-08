FROM ghcr.io/openclaw/openclaw:2026.3.2

# Override the default CMD to bind to all interfaces (0.0.0.0) instead of just localhost
# This allows external access through Zeabur's reverse proxy
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured", "--bind", "lan"]
