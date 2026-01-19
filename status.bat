@for /F %%x in ('"luvit -e print(os.date('^%%Y^%%m^%%d^%%H^%%M^%%S',os.time()))"') do set OUT=status-%%x.jsonl
echo %OUT%>status-last.txt
:loop
curl --rate 1/60s %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% %URL% | tee -a %OUT%
timeout 60
goto loop
