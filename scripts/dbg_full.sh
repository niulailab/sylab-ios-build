#!/bin/bash
docker logs --tail 120 tool-proxy 2>&1 | tail -90
echo DONE
