FROM ghcr.io/openclaw/openclaw:2026.3.2

RUN apt-get update && apt-get install -y socat && rm -rf /var/lib/apt/lists/*

EXPOSE 8080 18789

CMD node openclaw.mjs gateway --allow-unconfigured & (sleep 2 && socat TCP4-LISTEN:8080,reuseaddr TCP4:127.0.0.1:18789) & wait
