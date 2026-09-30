#!/bin/bash
P=/root/coze-studio/tool-proxy/server.py
line=$(sed -n '2871p' "$P")
echo "len=${#line}"
echo "contains_Bearer=$(case "$line" in *Bearer*) echo yes;; *) echo no;; esac)"
echo "contains_var_BOCHA_API_KEY=$(case "$line" in *BOCHA_API_KEY*) echo yes;; *) echo no;; esac)"
echo "contains_literal_keyprefix_skce=$(case "$line" in *sk-ce584c*) echo yes;; *) echo no;; esac)"
echo "contains_brace=$(case "$line" in *'{'*) echo yes;; *) echo no;; esac)"
# md5 of line for identity
printf '%s' "$line" | md5sum
echo "[DONE]"
