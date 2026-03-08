# OpenClaw application stage
FROM ghcr.io/openclaw/openclaw:2026.3.2 AS openclaw

# Final stage with nginx reverse proxy
FROM node:18-alpine

# Install nginx
RUN apk add --no-cache nginx

# Create startup script
RUN cat > /start.sh << 'EOF'
#!/bin/sh
set -e

# Start nginx in the background
nginx -g 'daemon off;' &
NGINX_PID=$!

# Wait a moment for nginx to start
sleep 1

# Start OpenClaw in the foreground
cd / && node openclaw.mjs gateway --allow-unconfigured --bind 0.0.0.0 &
OPENCLAW_PID=$!

# Wait for both processes
wait $NGINX_PID $OPENCLAW_PID
EOF

RUN chmod +x /start.sh

# Copy nginx configuration
RUN cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
  worker_connections 1024;
}

http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  log_format main '$remote_addr - $remote_user [$time_local] "$request" '
    '$status $body_bytes_sent "$http_referer" '
    '"$http_user_agent" "$http_x_forwarded_for"';

  access_log /var/log/nginx/access.log main;
  sendfile on;
  keepalive_timeout 65;

  # WebSocket support
  map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
  }

  upstream openclaw_backend {
    server 127.0.0.1:18789;
  }

  server {
    listen 8080;
    server_name _;

    # Proxy all requests to OpenClaw backend
    location / {
      proxy_pass http://openclaw_backend;
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection $connection_upgrade;
      proxy_set_header Host $host;
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header X-Forwarded-Proto $scheme;
      proxy_read_timeout 86400;
      proxy_send_timeout 86400;
    }
  }
}
EOF

# Copy OpenClaw from first stage
COPY --from=openclaw / /

# Expose port 8080 for HTTP access
EXPOSE 8080

# Run startup script
CMD ["/start.sh"]
