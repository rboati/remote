declare -a -r LOGLEVELS=( OFF FATAL ERROR WARN INFO DEBUG TRACE )
declare -a LOGCOLORS=( '0' '1;31' '31' '33' '34' '37'  '1' )
declare -i -r LOGLEVEL_DEFAULT=3

if [[ -z $LOGDOMAIN ]]; then	
	declare LOGDOMAIN="${BASH_SOURCE[1]##*/}"
fi

if [[ -z $LOGLEVEL ]]; then
	declare -i LOGLEVEL=$LOGLEVEL_DEFAULT
fi

if [[ -z $LOGCOLOR ]]; then	
	declare -i LOGCOLOR=1
fi

if [[ -z $LOGSINK ]]; then	
	declare LOGSINK=logsink_stderr_color
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
	declare -r LOGSUFFIXES=( none fatal err warn info debug trace )
	declare -i LEVEL i
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

set_loglevel() {
	local LEVEL="$1"
	declare -i i err=0

	if [[ $LEVEL =~ ^[0-9]+$ ]]; then
		if (( LEVEL < 0 )); then
			LEVEL=0
			err=1
		elif (( LOGLEVEL > ( ${#LOGLEVELS[@]} - 1 ) )); then
			LEVEL=$(( ${#LOGLEVELS[@]} - 1 ))
			err=2
		fi
	elif [[ $LEVEL =~ ^[A-Z]+$ ]]; then
		while : ; do
			for (( i=0; i < ${#LOGLEVELS[@]}; ++i )); do
				if [[ $LEVEL == ${LOGLEVELS[$i]} ]]; then
					LEVEL=$i
					break 2
				fi
			done
			LEVEL=$LOGLEVEL_DEFAULT
			err=3
			break
		done
	else
		LEVEL=$LOGLEVEL_DEFAULT
		err=4
	fi
	if [[ $LOGLEVEL != $LEVEL ]]; then
		LOGLEVEL=$LEVEL
		regenerate_logfunctions
	fi
	return $err
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

