FROM ghcr.io/openclaw/openclaw:2026.3.2

EXPOSE 8080

ENV PORT=8080
CMD ["node", "openclaw.mjs", "gateway", "--allow-unconfigured"]
