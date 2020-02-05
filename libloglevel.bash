[[ -n $LIBLOGLEVEL_VERSION ]] && return
declare -ir LIBLOGLEVEL_VERSION=1

declare -ar LOGLEVELS=( OFF FATAL ERROR WARN INFO DEBUG TRACE )
declare -a  LOGCOLORS=( '0' '1;31' '31' '33' '34' '37'  '1' )
declare -ir LOGLEVEL_DEFAULT=3

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
	declare LOGSINK='1>&2'
fi


generate_logfunctions() {
	declare -a LOGSUFFIXES=( none fatal err warn info debug trace )
	declare -i LEVEL i
	declare SUFFIX
	declare LEVELNAME
	declare COLOR
	declare -r RESET="\e[0m"
	declare TEMPLATE TEMPLATE_SINK

	for (( LEVEL=1; LEVEL<7; ++LEVEL )); do
		SUFFIX=${LOGSUFFIXES[$LEVEL]}
		LEVELNAME="${LOGLEVELS[$LEVEL]}"
		COLOR="\e[${LOGCOLORS[$LEVEL]}m"
			
		if (( LOGLEVEL >= LEVEL )); then
			if [[ $LOGCOLOR == 1 ]]; then
				TEMPLATE_SINK=$(cat <<- EOF
					{ 
						while read -r MSG; do printf '%b:%b:%s\n' "${COLOR}\$LOGDOMAIN${RESET}" "${COLOR}${LEVELNAME}${RESET}" "\$MSG"; done;
					} $LOGSINK
					EOF
				)
			else
				TEMPLATE_SINK=$(cat <<- EOF
					{ 
						while read -r MSG; do printf '%s:%s:%s\n' "\$LOGDOMAIN" "$LEVELNAME" "\$MSG"; done;
					} $LOGSINK
					EOF
				)
			fi
			TEMPLATE=$(cat <<- EOF
				log${SUFFIX}()   {
					declare -ir X=\$?; declare MSG;
					$TEMPLATE_SINK;
					return \$X;
				}
				echo${SUFFIX}()  {
					declare -ir X=\$?; declare MSG;
					printf '%s\n' "\$*" | $TEMPLATE_SINK;
					return \$X;
				}
				print${SUFFIX}() {
					declare -ir X=\$?; declare MSG; declare FMT="\$1"; shift;
					printf "\$FMT" "\$@" | $TEMPLATE_SINK;
					return \$X;
				}
				EOF
			)
		else
			TEMPLATE=$(cat <<- EOF
				log${SUFFIX}()   { return \$?; }
				echo${SUFFIX}()  { return \$?; }
				print${SUFFIX}() { return \$?; }
				EOF
			)
		fi

		eval "$TEMPLATE"
	done
}

## Example log functions
##
## logXXX functions log as level XXX their stdin
## echoXXX functions log as level XXX, similarly to the "echo" command
## printXXX functions log as level XXX, similarly to the "printf" command
##
  logfatal() { return $?; }
    logerr() { return $?; }
   logwarn() { return $?; }
   loginfo() { return $?; }
  logdebug() { return $?; }
  logtrace() { return $?; }
 echofatal() { return $?; }
   echoerr() { return $?; }
  echowarn() { return $?; }
  echoinfo() { return $?; }
 echodebug() { return $?; }
 echotrace() { return $?; }
printfatal() { return $?; }
  printerr() { return $?; }
 printwarn() { return $?; }
 printinfo() { return $?; }
printdebug() { return $?; }
printtrace() { return $?; }


##
## Arguments:
##   {LEVEL} : level number or level name
##
## Globals:
##   LOGLEVEL, LOGLEVEL_DEFAULT, LOGLEVELS, LOGCOLORS
##
## Returns:
##   0 : success
##   1 : underflow, cannot set the requested numeric level; level has been set to the minimum (0)
##   2 : overflow, cannot set the requested numeric level; level has been set to the maximum (6)
##   3 : unknown, cannot set the requested string level; level has been set to the default
##   4 : unknown garbage, cannot set the requested level; level has been set to the default
##
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
		generate_logfunctions
	fi
	return $err
}

__loglevel_init() {
	generate_logfunctions
}

__loglevel_init
