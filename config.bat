call setup
set OUT=config-%T%
echo %OUT%>data\config-last.txt

curl --parallel -L --verbose --remote-name-all --create-dirs --output-dir "data\%OUT%" ^
https://%HOST%/api/config ^
https://%HOST%/api/emoji ^
https://%HOST%/customjavascript ^
