#!/bin/bash
echo "=== models ==="
curl -s -m 20 "https://laneai.dev/v1/models" -H "Authorization: Bearer sk-bb71bcccb3854dab839ed20c2439d7709c3a75dff8080712" | head -c 3000
echo
echo DONE
