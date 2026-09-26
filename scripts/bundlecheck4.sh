#!/bin/bash
J=/tmp/ipachk2/ex/Payload/sylab.app/main.jsbundle
echo -n "FIX link-in-bold: "; grep -ao "FIX link-in-bold" "$J" | wc -l
echo -n "setMdPreviewUrl: "; grep -ao "setMdPreviewUrl" "$J" | wc -l
echo -n "openExternally: "; grep -ao "openExternally" "$J" | wc -l
echo -n "openURL: "; grep -ao "openURL" "$J" | wc -l
echo -n "2563eb: "; grep -ao "2563eb" "$J" | wc -l
echo -n "renderStyledContent survives? (function name may be mangled): "; grep -ao "renderStyledContent" "$J" | wc -l
echo "--- context around first 2563eb ---"
grep -ao ".\{40\}2563eb.\{20\}" "$J" | head -3