
declare -ga LOGLEVELS=( OFF FATAL ERROR WARN INFO DEBUG TRACE )
declare -ga LOGCOLORS=( 0  '1;31' '31' '33' '34' '37'  '1' )
declare -gi LOGLEVEL_DEFAULT=3

if [[ -z $LOGDOMAIN ]]; then
	declare -g LOGDOMAIN="${BASH_SOURCE[1]##*/}"
fi



generate_log_functions() {
	declare -a SUFFIXES=( "${LOGLEVELS[@],,}" )
	unset SUFFIXES[0]
	declare -i LEVEL i
	declare SUFFIX
	declare LEVELNAME
	declare COLOR
	declare -r RESET="\e[0m"
	declare TEMPLATE TEMPLATE_SINK

	if [[ -z $LOGLEVEL ]]; then
		declare -gi LOGLEVEL=$LOGLEVEL_DEFAULT
	fi
	if [[ -z $LOGCOLOR ]]; then
		declare -i LOGCOLOR=1
	fi
		
	if [[ -z $LOGSINK ]]; then
		declare LOGSINK='1>&2'
	fi

	for LEVEL in ${!SUFFIXES[@]}; do
		SUFFIX=${SUFFIXES[$LEVEL]}
		LEVELNAME="${LOGLEVELS[$LEVEL]}"
		COLOR="${LOGCOLORS[$LEVEL]}"
		if [[ -z $COLOR ]]; then
			COLOR='0'
		fi
		COLOR="\e[${COLOR}m"
			
		if (( LOGLEVEL >= LEVEL )); then
			if (( $LOGCOLOR == 1 )); then
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
  logerror() { return $?; }
   logwarn() { return $?; }
   loginfo() { return $?; }
  logdebug() { return $?; }
  logtrace() { return $?; }
 echofatal() { return $?; }
 echoerror() { return $?; }
  echowarn() { return $?; }
  echoinfo() { return $?; }
 echodebug() { return $?; }
 echotrace() { return $?; }
printfatal() { return $?; }
printerror() { return $?; }
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
##
set_loglevel() {
	declare LEVEL="$1"
	declare -i i err=0

	if [[ $LEVEL =~ ^[0-9]+$ ]]; then
		if (( LEVEL < 0 )); then
			LEVEL=0
			err=1
		elif (( LEVEL >= ${#LOGLEVELS[@]} )); then
			LEVEL=$(( ${#LOGLEVELS[@]} - 1 ))
			err=2
		fi
	else
		while : ; do
			for (( i=0; i< ${#LOGLEVELS[@]}; ++i )); do
				if [[ $LEVEL == ${LOGLEVELS[$i]} ]]; then
					LEVEL=$i
					break 2
				fi
			done
			LEVEL=$LOGLEVEL_DEFAULT
			err=3
			break
		done
	fi
	LOGLEVEL=$LEVEL generate_log_functions
	return $err
}

generate_log_functions


