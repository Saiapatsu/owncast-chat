@for /F %%x in ('"luvit -e print(os.date('^%%Y^%%m^%%d^%%H^%%M^%%S',os.time()))"') do set t14=%%x
ncat -lk 54197 | websocat %WS% | tee -a wss-%t14%.txt
