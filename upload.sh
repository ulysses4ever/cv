#! /bin/bash
# lcd "$LOC_FOLDER"
# . copy-it202-constants.sh
#cd "~/public_html"
#put cv.pdf
#bye
#ulysses
#ftp edu.mmcs.sfedu.ru <<ENDOFUPLOAD
#(@sun)ul
#ENDOFUPLOAD
USER=ulysses
PASS=241mos16cow40
curl --user $USER:${PASS} --upload-file cv.pdf ftp://staff.mmcs.sfedu.ru/public_html/

