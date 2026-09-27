#!/usr/bin/env bash
set +e
H=/root/coze-studio/docker/atlas/opencoze_latest_schema.hcl
echo "######## A. atlas hcl presence ########"
ls -la "$H" 2>/dev/null; echo "size $(wc -l < "$H" 2>/dev/null) lines"
echo
echo "######## B. table blocks defined in HCL ########"
grep -nE 'table\s+"' "$H" | sed -E 's/.*table\s+"([^"]+)".*/\1/' | sort -u
echo
echo "######## C. sylab-custom tables present? (grep known names) ########"
for t in user_credits recharge_order tool chat_billing skill;do
 echo "-- $t --"; grep -nE "table\s+\"$t\"" "$H" | head
done
echo
echo "######## D. how server invoked: atlas container / compose ########"
grep -rnE "atlas" /root/coze-studio/docker/docker-compose*.yml 2>/dev/null | head -20
echo
echo "######## E. custom backend compose services list ########"
ls -1 /root/coze-studio/docker/*.yml 2>/dev/null
echo
RECON_ATLAS_DONE
