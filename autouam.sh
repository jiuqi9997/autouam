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

keeptime="300"
# ≈开盾最小时间，如60 则开盾60秒内负载降低不会关，60秒后关

interval="0.5"
# 检测间隔时间，默认0.5秒

email="wdnmd@cloudflare.com"
# CloudFlare 账号邮箱

api_key="(´இ皿இ｀)"
# CloudFlare API KEY

zone_id="ಥ_ಥ"
# 区域ID 在域名的概述页面获取

default_security_level="high"
# 默认安全等级 关闭UAM时将会把安全等级调整为它

api_url="https://api.cloudflare.com/client/v4/zones/$zone_id/settings/security_level"
# API的地址

api_url1="https://api.cloudflare.com/client/v4/zones/$zone_id/firewall/access_rules/rules"
# API的地址之二

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
        rulesid=$(curl -X GET "$api_url1?per_page=1000&mode=challenge&configuration.target=country" \
            -H "X-Auth-Email: $email" \
            -H "X-Auth-Key: $api_key" \
            -H "Content-Type: application/json" \
            --silent \
        | jq -r '.result[].id')
        for i in $rulesid
        do
            result=$(curl -X DELETE "$api_url1/$i" \
                -H "X-Auth-Email: $email" \
                -H "X-Auth-Key: $api_key" \
                -H "Content-Type: application/json" \
                --data "{
                    \"cascade\": \"none\"
                }" --silent \
            | jq -r '.success')
            if [ "$result" = "true" ]; then
                echo -e "\n删除验证码 成功 ID: $i"
            fi
        done
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
        for i in AF AX AL DZ AS AD AO AI AQ AG AR AM AW AU AT AZ BS BH BD BB BY BE BZ BJ BM BT BO BQ BA BW BV BR IO BN BG BF BI KH CM CA CV KY CF TD CL CN CX CC CO KM CG CD CK CR CI HR CU CW CY CZ DK DJ DM DO EC EG SV GQ ER EE ET FK FO FJ FI FR GF PF TF GA GM GE DE GH GI GR GL GD GP GU GT GG GN GW GY HT HM VA HN HK HU IS IN ID IR IQ IE IM IL IT JM JP JE JO KZ KE KI KP KR KW KG LA LV LB LS LR LY LI LT LU MO MK MG MW MY MV ML MT MH MQ MR MU YT MX FM MD MC MN ME MS MA MZ MM NA NR NP NL NC NZ NI NE NG NU NF MP NO OM PK PW PS PA PG PY PE PH PN PL PT PR QA RE RO RU RW BL SH KN LC MF PM VC WS SM ST SA SN RS SC SL SG SX SK SI SB SO ZA GS SS ES LK SD SR SJ SZ SE CH SY TW TJ TZ TH TL TG TK TO TT TN TR TM TC TV UG UA AE GB UM UY UZ VU VE VN VG VI WF EH YE ZM ZW XX T1
        do
            result=$(curl -X POST "$api_url1" \
                -H "X-Auth-Email: $email" \
                -H "X-Auth-Key: $api_key" \
                -H "Content-Type: application/json" \
                --data "{
                    \"mode\": \"challenge\",
                    \"configuration\": {
                        \"target\": \"country\",
                        \"value\": \"$i\"
                    }
                }" --silent \
            | jq -r '.success')
            if [ "$result" = "true" ]; then
            echo -e "\n开启对$i国家的验证码 成功"
            fi
        done
    fi
else
echo 0 > status.txt
fi
sleep $interval
clear
done
