#/bin/bash

DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd -P)"
NAME="${0##*/}"

source "${DIR}/loglevel.bash"

inside_function1 () {
	local LOGDOMAIN="function1"
	"echo$level" "echo$level" "inside function1"
	"print$level" "%s %s" "print$level" "inside function1"
	inside_function2
}

inside_function2 () {
	local LOGDOMAIN="function2"
	"echo$level" "echo$level" "inside function2"
	"print$level" "%s %s" "print$level" "inside function2"
	inside_function3
}

inside_function3 () {
	local LOGDOMAIN="function3"
	"echo$level" "echo$level" "inside function3"
	"print$level" "%s %s" "print$level" "inside function3"
}

for LOGLEVEL in $(seq 0 6); do
	regenerate_logfunctions
	echo -e "\e[1;37mLOGLEVEL=$LOGLEVEL (${LOGLEVELS[$LOGLEVEL]})\e[0m"
	msglevel=1
	for level in fatal err warn info debug trace; do
		echo -e "\e[37mTesting messages at level $msglevel (${LOGLEVELS[$msglevel]})\e[0m"
		inside_function1
		"echo$level" "echo$level" "outside"
		"print$level" "%s %s" "print$level" "outside"
		ls | LOGDOMAIN=ls log$level
		: $((msglevel++))
	done
	echo
done

