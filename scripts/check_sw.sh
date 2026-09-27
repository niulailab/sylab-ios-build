grep -n "sw.js\|serviceWorker" /var/www/chat-sdk/index.html || echo "no sw ref in index.html"
echo "--- head sw.js ---"; head -5 /var/www/chat-sdk/sw.js
