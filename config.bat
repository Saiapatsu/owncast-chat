call setup
set OUT=config-%T%
echo %OUT%>config-last.txt

curl --parallel -L --verbose --remote-name-all --create-dirs --output-dir "%OUT%" ^
https://%HOST%/api/config ^
https://%HOST%/api/emoji ^
https://%HOST%/customjavascript ^
