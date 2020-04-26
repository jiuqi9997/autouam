#!/bin/bash

#
# Usage:
# screen -dmS autouam &&
# screen -x -S autouam -p 0 -X stuff "bash /root/autouam.sh" &&
# screen -x -S autouam -p 0 -X stuff $'\n'
#

mode="load"
# 两种模式可选，一：cpu 二：load

keeptime="60"
# ≈开盾最小时间，如60 则开盾60秒内负载降低不会关，60秒后关

email="fnmdp@gov.cn"
# CloudFlare 账号邮箱

api_key="(ಡωಡ)"
# CloudFlare API KEY

zone_id="(´இ皿இ｀)"
# 区域ID 在域名的概述页面获取

default_security_level="high"
# 默认安全等级 关闭UAM时将会把安全等级调整为它

api_url="https://api.cloudflare.com/client/v4/zones/$zone_id/settings/security_level"
# API的地址

for((;;))
do
if [ "$mode" = "cpu" ];
then
check=90   #5秒内CPU连续超过80 则开启UAM【可以根据您的服务器负荷情况调整】
#系统空闲时间
TIME_INTERVAL=5
time=$(date "+%Y-%m-%d %H:%M:%S")
LAST_CPU_INFO=$(cat /proc/stat | grep -w cpu | awk '{print $2,$3,$4,$5,$6,$7,$8}')
LAST_SYS_IDLE=$(echo $LAST_CPU_INFO | awk '{print $4}')
LAST_TOTAL_CPU_T=$(echo $LAST_CPU_INFO | awk '{print $1+$2+$3+$4+$5+$6+$7}')
sleep ${TIME_INTERVAL}
NEXT_CPU_INFO=$(cat /proc/stat | grep -w cpu | awk '{print $2,$3,$4,$5,$6,$7,$8}')
NEXT_SYS_IDLE=$(echo $NEXT_CPU_INFO | awk '{print $4}')
NEXT_TOTAL_CPU_T=$(echo $NEXT_CPU_INFO | awk '{print $1+$2+$3+$4+$5+$6+$7}')

#系统空闲时间
SYSTEM_IDLE=`echo ${NEXT_SYS_IDLE} ${LAST_SYS_IDLE} | awk '{print $1-$2}'`
#CPU总时间
TOTAL_TIME=`echo ${NEXT_TOTAL_CPU_T} ${LAST_TOTAL_CPU_T} | awk '{print $1-$2}'`
load=`echo ${SYSTEM_IDLE} ${TOTAL_TIME} | awk '{printf "%.2f", 100-$1/$2*100}'`
else
load=$(cat /proc/loadavg | colrm 5)
check=$(cat /proc/cpuinfo | grep "processor" | wc -l)

fi

if [ ! -f "status.txt" ];then
echo "" > status.txt
else
status=$(cat status.txt)
fi
now=$(date +%s)
time=$(date +%s -r status.txt)



echo "当前$mode负载:$load"
if [[ $status -eq 1 ]]
then
echo "UAM ON!"
else
echo "UAM OFF!"
fi

newtime=`expr $now - $time`
closetime=`expr $keeptime - $newtime`

if [[ $load <$check ]]&&[[ $status -eq 1 ]]&&[[ $newtime -gt $keeptime ]]
then
    echo -e "\n$mode负载低于$check，当前已开盾超过规定时间（$keeptime）($newtime秒)，尝试调整至默认安全等级（$default_security_level）"
    # Disable Under Attack Mode
    result=$(curl -X PATCH "$api_url" \
        -H "X-Auth-Email: $email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json" \
        --data "{\"value\": \"$default_security_level\"}" --silent \
        | jq -r '.success')
    if [ "$result" = "true" ]; then
        echo 0 > status.txt
        echo -e "\n成功"
    fi

elif [[ $load <$check ]]
then
    echo -e "\n$mode负载低于$check，不做任何改变，状态持续了$newtime秒"
    if [[ $status -eq 1 ]]
    then
        echo -e "将于$closetime秒后调整安全等级至$default_security_level"
    fi

elif [[ $load >$check ]] && [[ $status -eq 1 ]] && [[ $newtime -gt $keeptime ]]
then
    echo -e "\n$mode负载高于$check，当前已开启UAM超过$keeptime秒，UAM无效"
elif [[ $load >$check ]] && [[ $status -eq 1 ]]
then
    echo -e "\n$mode负载高于$check，当前已开启($newtime秒)，请再观察"
elif [[ $load >$check ]]
then
    echo -e "\n$mode负载高于$check，开启UAM"
    # Enable Under Attack Mode
    result=$(curl -X PATCH "$api_url" \
        -H "X-Auth-Email: $email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json" \
        --data '{"value": "under_attack"}' --silent \
        | jq -r '.success')
    if [ "$result" = "true" ]; then
        echo 1 > status.txt
        echo -e "\n成功"
    fi
else
echo 0 > status.txt
fi
sleep 0.5
clear
done
