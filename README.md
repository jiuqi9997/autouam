# autouam
通过检测系统负载（cpu或load）自动开启cloudflare UAM和challenge（验证码）

注意！默认challenge=1，将在开启UAM的同时开启验证码。如果你不想，请将它设为0
# 使用方法
* 在`dash.cloudflare.com`生成过去apikey，将它们填入脚本内。
* 执行`screen -dmS autouam && screen -x -S autouam -p 0 -X stuff "bash /root/autouam.sh" && screen -x -S autouam -p 0 -X stuff $'\n'`启动脚本，注意替换脚本路径。
* 执行`screen -r autouam -d`查看运行状态，ctrl+A+D断开screen，脚本继续运行。
