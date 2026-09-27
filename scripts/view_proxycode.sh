#!/bin/bash
docker exec tool-proxy sh -lc 'sed -n "2074,2160p" /app/server.py'
echo DONE
