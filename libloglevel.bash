
declare -ga LOGLEVELS=( OFF FATAL ERROR WARN INFO DEBUG TRACE )
declare -ga LOGCOLORS=( 0  '1;31' '31' '33' '34' '37'  '1' )
declare -gi LOGLEVEL_DEFAULT=3

if [[ -z $LOGDOMAIN ]]; then
	declare -g LOGDOMAIN="${BASH_SOURCE[1]##*/}"
fi



logdomain_filter() {
	local prefix="$1"
	local IFS='' msg
	while read -r msg; do
		printf '%b%s\n' "$prefix" "$msg"
	done
}

loglevel_filter() {
	local prefix="$1"
	local IFS='' msg
	while read -r msg; do
		printf '%b%s\n' "$prefix" "$msg"
	done
}


generate_log_functions() {
	local -i loglevel="${1:-$LOGLEVEL_DEFAULT}"
	local -a suffixes=( "${LOGLEVELS[@],,}" )
	unset 'suffixes[0]'
	local -i level fd
	local suffix
	local level_name
	local color reset
	local template

	for (( level=0; level<${#LOGLEVELS[@]}; ++level)); do
		(( fd=100+level ))
		eval "exec ${fd}>&-"
	done

	if [[ -z $LOGCOLOR ]]; then
		declare -i LOGCOLOR=1
	fi

	if [[ -z $LOGSINK ]]; then
		declare LOGSINK='1>&2'
	fi

	for level in "${!suffixes[@]}"; do
		suffix=${suffixes[$level]}
		level_name="${LOGLEVELS[$level]}"
		(( fd=100+level ))

		if (( LOGCOLOR == 1 )); then
			color="${LOGCOLORS[$level]}"
			[[ -z $color ]] && color='0'
			color="\e[${color}m"
			reset="\e[0m"
		else
			color=''
			reset=''
		fi

		if (( loglevel >= level )); then
			template=$(cat <<- EOF
				exec ${fd}>&2;
				exec ${fd}> >(loglevel_filter "${color}${level_name}${reset}:" $LOGSINK;);

				log${suffix}()   {
					declare -ir X=\$?;
					cat > >(logdomain_filter "${color}\$LOGDOMAIN${reset}:" >&${fd};);
					return \$X;
				}
				echo${suffix}()  {
					declare -ir X=\$?; declare msg;
					printf '%b:%s\n' "${color}\$LOGDOMAIN${reset}" "\$*" >&${fd};
					return \$X;
				}
				print${suffix}() {
					declare -ir X=\$?; declare msg; declare FMT="\$1"; shift;
					printf "${color}\$LOGDOMAIN${reset}:\$FMT\n" "\$@" >&${fd};
					return \$X;
				}
				EOF
			)
			eval "$template"
			template+=$(cat <<- EOF
				EOF
			)
		else
			template=$(cat <<- EOF
				log${suffix}()   { declare -ir X=\$?; cat > /dev/null; return \$X; }
				echo${suffix}()  { return \$?; }
				print${suffix}() { return \$?; }
				EOF
			)
		fi
		eval "$template"
		# shellcheck disable=SC2034
		declare -gi LOGLEVEL="$loglevel"
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
##   {level} : level number or level name
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
	declare level="$1"
	declare -i i err=0

	if [[ $level =~ ^[0-9]+$ ]]; then
		if (( level < 0 )); then
			level=0
			err=1
		elif (( level >= ${#LOGLEVELS[@]} )); then
			level=$(( ${#LOGLEVELS[@]} - 1 ))
			err=2
		fi
	else
		while : ; do
			for (( i=0; i< ${#LOGLEVELS[@]}; ++i )); do
				if [[ ${level,,} == "${LOGLEVELS[$i],,}" ]]; then
					level=$i
					break 2
				fi
			done
			level=$LOGLEVEL_DEFAULT
			err=3
			break
		done
	fi
	generate_log_functions $level
	return $err
}



