#!/bin/sh
# Checks that the running server delivers the page, the client program and the style sheet.
# Usage: ./tests/smoke.sh [url]   (default: http://localhost:8080)

URL=${1:-http://localhost:8080}
FAILED=0

check() {
	if [ "$2" = "$3" ]; then
		echo "OK   $1"
	else
		echo "FAIL $1 (expected $3, got $2)"
		FAILED=1
	fi
}

status() {
	curl -s -o /dev/null -w "%{http_code}" "$1"
}

PAGE=$(curl -s "$URL/")

check "page is served" "$(status "$URL/")" "200"
check "client program is served" "$(status "$URL/h42n42.js")" "200"
check "style sheet is served" "$(status "$URL/css/h42n42.css")" "200"
check "page has the board" "$(echo "$PAGE" | grep -c 'class="board')" "1"
check "page has the river" "$(echo "$PAGE" | grep -c 'class="river')" "1"
check "page has the hospital" "$(echo "$PAGE" | grep -c 'class="hospital')" "1"
check "page has the game over message" "$(echo "$PAGE" | grep -c 'GAME OVER')" "1"
check "page loads the client program" "$(echo "$PAGE" | grep -c 'h42n42.js')" "1"

exit $FAILED
