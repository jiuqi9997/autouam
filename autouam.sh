#!/bin/bash

#
# Usage:
# screen -dmS autouam &&
# screen -x -S autouam -p 0 -X stuff "bash /root/autouam.sh" &&
# screen -x -S autouam -p 0 -X stuff $'\n'
#

mode="load"
# 两种模式可选，一：cpu 二：load

challenge="1"
# 是否同时开启验证码质询 设为1即开启

keeptime="30"
# ≈开盾最小时间，如60 则开盾60秒内负载降低不会关，60秒后关

interval="0.5"
# 检测间隔时间，默认0.5秒

email="눈_눈"
# CloudFlare 账号邮箱

api_key="눈_눈"
# CloudFlare API KEY

zone_id="눈_눈"
# 区域ID 在域名的概述页面获取

default_security_level="high"
# 默认安全等级 关闭UAM时将会把安全等级调整为它

api_url="https://api.cloudflare.com/client/v4/zones/$zone_id/settings/security_level"
# API的地址

api_url1="https://api.cloudflare.com/client/v4/zones/$zone_id/firewall/rules"
# API的地址之二

api_url2="https://api.cloudflare.com/client/v4/zones/$zone_id/filters"
# API的地址之三

# 安装依赖
if [ ! $(which jq 2> /dev/null) ]; then
    echo "jq not found!"
    if [ -f "/usr/bin/yum" ] && [ -d "/etc/yum.repos.d" ]; then
        yum install jq -y
    elif [ -f "/usr/bin/apt-get" ] && [ -f "/usr/bin/dpkg" ]; then
        apt-get install jq -y
    fi
fi

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
if [ -f "ruleid.txt" ]; then
ruleid=$(cat ruleid.txt)
fi
if [ -f "filterid.txt" ]; then
filterid=$(cat filterid.txt)
fi
now=$(date +%s)
time=$(date +%s -r status.txt)



echo "当前$mode负载:$load"
if [[ $status -eq 1 ]]
then
echo "UAM ON!"
if [ "$challenge" -eq 1 ]; then
echo "Challenge ON!"
fi
else
echo "UAM OFF!"
if [ "$challenge" -eq 1 ]; then
echo "Challenge OFF!"
fi
fi

newtime=`expr $now - $time`
closetime=`expr $keeptime - $newtime`

if [[ $load <$check ]]&&[[ $status -eq 1 ]]&&[[ $newtime -gt $keeptime ]]
then
    echo -e "\n$mode负载低于$check，当前已开盾超过规定时间$newtime秒，尝试调整至默认安全等级（$default_security_level）"
    # Disable Under Attack Mode
    result=$(curl -X PATCH "$api_url" \
        -H "X-Auth-Email: $email" \
        -H "X-Auth-Key: $api_key" \
        -H "Content-Type: application/json" \
        --data "{
            \"value\": \"$default_security_level\"
        }" --silent \
    | jq -r '.success')
    if [ "$result" = "true" ]; then
        echo 0 > status.txt
        echo -e "\n成功"
    fi
    if [ "$challenge" -eq 1 ]; then
        result=$(curl -X DELETE "$api_url1/$ruleid" \
            -H "X-Auth-Email: $email" \
            -H "X-Auth-Key: $api_key" \
            -H "Content-Type: application/json" \
            --silent)
        result1=$(curl -X DELETE "$api_url2/$filterid" \
            -H "X-Auth-Email: $email" \
            -H "X-Auth-Key: $api_key" \
            -H "Content-Type: application/json" \
            --silent)
        if [ $(echo $result | jq -r '.success') -a $(echo $result1 | jq -r '.success') ]; then
            echo -e "\n验证码关闭成功"
        fi
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
            --data "{
                \"value\": \"under_attack\"
            }" --silent \
    | jq -r '.success')
    if [ "$result" = "true" ]; then
        echo 1 > status.txt
        echo -e "\n成功"
    fi
    if [ "$challenge" -eq 1 ]; then
        while :
            do
            result=$(curl -X POST "$api_url2" \
                -H "X-Auth-Email: $email" \
                -H "X-Auth-Key: $api_key" \
                -H "Content-Type: application/json" \
                --data '[{
                    "expression": "(not cf.client.bot)"
                }]' --silent)
            if [ $(echo $result | jq -r '.success') == "true" ]; then
                filterid=$(echo $result | jq -r '.result[].id')
            else
                filterid=$(echo $result | jq -r '.errors[].meta.id')
                for i in $filterid
                do
                result1=$(curl -X DELETE "$api_url2/$i" \
                    -H "X-Auth-Email: $email" \
                    -H "X-Auth-Key: $api_key" \
                    -H "Content-Type: application/json" --silent)
                done
                if [ $(echo $result1 | jq -r '.success') ]; then
                    echo "\n冲突的filter删除成功"
                fi
            fi
            if [ $(echo $result | jq -r '.success') == "true" ]; then
                break
            fi
        done
        result=$(curl -X POST "$api_url1" \
            -H "X-Auth-Email: $email" \
            -H "X-Auth-Key: $api_key" \
            -H "Content-Type: application/json" \
            --data "[{
                \"action\": \"challenge\",
                \"filter\": {
                    \"id\": \"$filterid\",
                    \"expression\": \"(not cf.client.bot)\"
                }
            }]" --silent)
        if [ $(echo $result | jq -r '.success') == "true" ]; then
            ruleid=$(echo $result | jq -r '.result[].id')
            echo "$filterid" > filterid.txt
            echo "$ruleid" > ruleid.txt
            echo -e "验证码开启成功，规则id：$ruleid"
        fi
    fi
else
echo 0 > status.txt
fi
sleep $interval
clear
done
