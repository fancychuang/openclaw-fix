# OpenClaw application stage
FROM ghcr.io/openclaw/openclaw:2026.3.2 AS openclaw

# nginx reverse proxy stage with Node.js support
FROM node:18-alpine

# Install nginx
RUN apk add --no-cache nginx

# Copy nginx config
COPY <<EOF /etc/nginx/nginx.conf
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
  
  # WebSocket upgrades
  map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
  }
  
  upstream openclaw_backend {
    server 127.0.0.1:18789;
  }
  
  server {
    listen 8080 default_server;
    server_name _;
    
    # WebSocket proxy
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
    }
  }
}
EOF

# Copy OpenClaw from first stage
COPY --from=openclaw / /

# Set working directory
WORKDIR /app

# Expose both OpenClaw WebSocket (18789) and nginx HTTP (8080)
EXPOSE 8080 18789

# Start both services: nginx and OpenClaw
CMD ["sh", "-c", "nginx -g 'daemon off;' & cd / && node openclaw.mjs gateway --allow-unconfigured --bind 0.0.0.0 --listen-port 18789 && wait"]
