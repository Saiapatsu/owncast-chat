call setup
set URL=https://%HOST%/api/chat?accessToken=%TOKEN%
set OUT=chat-%T%.json
echo %OUT%>chat-last.txt

curl %URL% > %OUT%
