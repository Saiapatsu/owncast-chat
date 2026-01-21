set HOST=
set TOKEN=
@for /F %%x in ('"luvit -e print(os.date('^%%Y^%%m^%%d^%%H^%%M^%%S',os.time()))"') do set T=%%x
mkdir data
