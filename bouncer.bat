@for /F %%x in ('"luvit -e print(os.date('^%%Y^%%m^%%d^%%H^%%M^%%S',os.time()))"') do set OUT=wss-%%x.jsonl
echo %OUT%>lastout.txt
ncat -lk 54197 | websocat %WS% | tee -a %OUT%
