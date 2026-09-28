#!/bin/bash
sed -n '228,257p' /etc/nginx/sites-enabled/default
echo "=== file real path / inode ==="
ls -la /etc/nginx/sites-enabled/default
readlink -f /etc/nginx/sites-enabled/default
