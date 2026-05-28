:start

call setup
@set URL=wss://%HOST%/ws?accessToken=%TOKEN%
set OUT=wss-%T%.jsonl
echo %OUT%>data\wss-last.txt

@ncat -lk %WSSPORT% | websocat --exit-on-hangup %URL% | tee -a data\%OUT%
echo {"type":"META","body":"Bouncer disconnected"}>>data\%OUT%

goto start
