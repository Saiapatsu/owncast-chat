call setup
set URL=https://%HOST%/api/status
set OUT=status-%T%.jsonl
echo %OUT%>status-last.txt

:loop
curl --rate 1/60s %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% | tee -a %OUT%
timeout 60
goto loop
