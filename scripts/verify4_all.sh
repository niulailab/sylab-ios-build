#!/usr/bin/env bash
exec > /var/www/sylab-ios/verify4_0930.txt 2>&1
set +e
MP=$(docker exec coze-mysql printenv MYSQL_ROOT_PASSWORD)
Q(){ docker exec coze-mysql mysql -uroot -p"$MP" -N -e "$1" opencoze 2>&1; }
echo "##### 1. schedule_runs 列"
Q "SHOW COLUMNS FROM sylab_schedule_runs;" | awk '{print $1}'
echo
echo "##### 2. compose 文件"
ls -la /root/coze-studio/*.yml /root/coze-studio/*.yaml /root/coze-studio/docker/*.yml 2>/dev/null
echo
echo "##### 3. coze-server compose 归属"
docker inspect coze-server --format 'project={{index .Config.Labels "com.docker.compose.project"}} workdir={{index .Config.Labels "com.docker.compose.project.working_dir"}} config={{index .Config.Labels "com.docker.compose.project.config_files"}} service={{index .Config.Labels "com.docker.compose.service"}}'
echo "----- tool-proxy -----"
docker inspect tool-proxy --format 'project={{index .Config.Labels "com.docker.compose.project"}} workdir={{index .Config.Labels "com.docker.compose.project.working_dir"}} config={{index .Config.Labels "com.docker.compose.project.config_files"}} service={{index .Config.Labels "com.docker.compose.service"}}'
echo
echo "##### 4. coze-server resolv.conf"
docker exec coze-server cat /etc/resolv.conf
echo
echo "##### 5. 网络网段/网关"
docker network inspect coze-studio_coze-network --format 'subnet={{range .IPAM.Config}}{{.Subnet}} gw={{.Gateway}}{{end}}'
echo
echo "##### 6. 调度代码位置(含 sylab_scheduled_tasks 的文件)"
grep -rln "sylab_scheduled_tasks" /root/coze-studio --include="*.go" 2>/dev/null
