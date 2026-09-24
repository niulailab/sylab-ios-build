#!/bin/bash
set -e

CURRENT_VERSION=$(python3 -c "import json; print(json.load(open('app.json'))['expo']['version'])")
CURRENT_BUILD=$(python3 -c "import json; print(json.load(open('app.json'))['expo']['ios']['buildNumber'])")

PREV_VERSION=$(git show HEAD~1:app.json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['expo']['version'])" 2>/dev/null || echo "")
PREV_BUILD=$(git show HEAD~1:app.json 2>/dev/null | python3 -c "import json,sys; print(json.load(sys.stdin)['expo']['ios']['buildNumber'])" 2>/dev/null || echo "")

if [ -z "$PREV_VERSION" ]; then
    echo "First commit, skipping version check"
    exit 0
fi

if [ "$CURRENT_VERSION" = "$PREV_VERSION" ] && [ "$CURRENT_BUILD" = "$PREV_BUILD" ]; then
    echo "ERROR: version not bumped!"
    echo "  Current: version=$CURRENT_VERSION build=$CURRENT_BUILD"
    echo "  Previous: version=$PREV_VERSION build=$PREV_BUILD"
    exit 1
fi

echo "OK: version bumped $PREV_VERSION/$PREV_BUILD -> $CURRENT_VERSION/$CURRENT_BUILD"
