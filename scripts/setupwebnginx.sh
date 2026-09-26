#!/bin/bash
set -e
echo "===== port 80 listeners ====="
ss -ltnp | grep -E ':80 ' || echo "nothing on 80"
WB=/root/sylab-app/web-build
CONF=/etc/nginx/sites-available/sylab-web
cat > "$CONF" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name web.symsgf.xyz;

    root $WB;
    index index.html;

    # gzip
    gzip on;
    gzip_types text/css application/javascript application/json image/svg+xml;

    location / {
        try_files \$uri \$uri/ /index.html;
    }
}
EOF
ln -sf "$CONF" /etc/nginx/sites-enabled/sylab-web
nginx -t
systemctl reload nginx
echo "===== local curl ====="
curl -s -o /dev/null -w "localhost http=%{http_code}\n" -H "Host: web.symsgf.xyz" http://127.0.0.1/
curl -s -H "Host: web.symsgf.xyz" http://127.0.0.1/ | head -20
