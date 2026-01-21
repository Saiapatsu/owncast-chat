call setup
set URL=https://%HOST%/api/chat?accessToken=%TOKEN%
set OUT=chat-%T%.json
echo %OUT%>data\chat-last.txt

curl %URL% > data\%OUT%
