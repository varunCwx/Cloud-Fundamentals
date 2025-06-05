#!/bin/sh
set -e

# Substitute BACKEND_URL in index.html
envsubst < /usr/share/nginx/html/index.html > /usr/share/nginx/html/index.tmp \
    && mv /usr/share/nginx/html/index.tmp /usr/share/nginx/html/index.html

# Start nginx
nginx -g 'daemon off;'
