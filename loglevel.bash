declare -r LOGLEVELS=( OFF FATAL ERROR WARN INFO DEBUG TRACE )
declare -r LOGCOLORS=( '0' '1;31' '31' '33' '34' '37'  '1' )

if [[ -z $LOGDOMAIN ]]; then	
	LOGDOMAIN="${BASH_SOURCE[1]##*/}"
fi

if [[ -z $LOGLEVEL ]]; then	
	declare -i LOGLEVEL=3
fi

if [[ -z $LOGCOLOR ]]; then	
	declare -i LOGCOLOR=1
fi

if [[ -z $LOGSINK ]]; then	
	LOGSINK=logsink_stderr_color
fi

logsink_stdout() {
	declare -i LEVEL="$1"
	while read -r MSG; do
		printf '%s:%s:%s\n' "$LOGDOMAIN" "${LOGLEVELS[$LEVEL]}" "$MSG"
	done
}

logsink_stderr() {
	logsink_stdout "$@" 1>&2
}

logsink_stdout_color() {
	declare -i LEVEL="$1"
	local COLOR="\e[${LOGCOLORS[$LEVEL]}m"
	local MSG
	while read -r MSG; do
		printf '%b:%b:%s\n' "${COLOR}$LOGDOMAIN\e[0m" "${COLOR}${LOGLEVELS[$LEVEL]}\e[0m" "$MSG"
	done
}

logsink_stderr_color() {
	logsink_stdout_color "$@" 1>&2
}

regenerate_logfunctions() {
	declare -r LOGSUFFIXES=( _ fatal err warn info debug trace )
	declare -i LEVEL
	local SUFFIX TEMPLATE
	for (( LEVEL=1; LEVEL<7; ++LEVEL )); do
		SUFFIX=${LOGSUFFIXES[$LEVEL]}
		if (( LOGLEVEL >= $LEVEL )); then
			TEMPLATE=$(cat <<- EOF
				log${SUFFIX}() { '$LOGSINK' $LEVEL; }
				echo${SUFFIX}() { printf '%s\n' "\$*" | '$LOGSINK' $LEVEL; }
				print${SUFFIX}() { local FMT="\$1"; shift; printf "\$FMT" "\$@" | '$LOGSINK' $LEVEL; }
				EOF
			)
		else
			TEMPLATE=$(cat <<- EOF
				log${SUFFIX}() { :; }
				echo${SUFFIX}() { :; }
				print${SUFFIX}() { :; }
				EOF
			)
		fi
		eval "$TEMPLATE"
	done
}

  logfatal() { :; }
    logerr() { :; }
   logwarn() { :; }
   loginfo() { :; }
  logdebug() { :; }
  logtrace() { :; }

 echofatal() { :; }
   echoerr() { :; }
  echowarn() { :; }
  echoinfo() { :; }
 echodebug() { :; }
 echotrace() { :; }

printfatal() { :; }
  printerr() { :; }
 printwarn() { :; }
 printinfo() { :; }
printdebug() { :; }
printtrace() { :; }

regenerate_logfunctions

