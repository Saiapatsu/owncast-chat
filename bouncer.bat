call setup
set URL=wss://%HOST%/ws?accessToken=%TOKEN%
set OUT=wss-%T%.jsonl
echo %OUT%>wss-last.txt

ncat -lk 54197 | websocat --exit-on-hangup %URL% | tee -a %OUT%
echo {"type":"META","body":"Bouncer disconnected"}>>%OUT%
