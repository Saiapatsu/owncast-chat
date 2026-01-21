call setup
set URL=https://%HOST%/api/status
set OUT=status-%T%.jsonl
echo %OUT%>data\status-last.txt

:loop
curl --rate 1/60s %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% | tee -a data\%OUT%
timeout 60
goto loop
