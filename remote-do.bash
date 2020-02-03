#/bin/bash

DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd -P)"
NAME="${0##*/}"

[[ -z $LOGLEVEL ]] && LOGLEVEL=4
source "${DIR}/loglevel.bash"

source "${DIR}/remote.bash"

OPT_INTERACTIVE=yes
OPT_SITES=()
OPT_CONFS=()

while [ $# -gt 0 ]; do
	case "$1" in
		-y|--yes)
			shift
			OPT_INTERACTIVE=no
			;;
		-c|--conf)
			shift
			OPT_CONF="${1##*/}"
			OPT_CONFS+=("$OPT_CONF")
			shift
			;;
		-t)
			shift
			OPT_CONFS+=(test)
			;;
		-l)
			shift
			OPT_CONFS+=(live)
			;;
		-s|--site)
			shift
			OPT_SITES+=("${1}")
			shift
			;;
		-q|--quiet)
			shift
			OPT_QUIET=yes
			OPT_INTERACTIVE=no
			;;
		--)
			shift
			break
			;;
		-*)
			echoerr "Unknown option '$1'"
			exit 1
			;;
		*)
			break
	esac
done

if [[ ${#OPT_CONFS[@]} == 0 ]]; then
	# default conf
	OPT_CONFS+=(test)
fi
echotrace "OPT_CONFS=(${OPT_CONFS[@]})."

exec 6<&0 # save stdin

ctrl_c_trap() {
	echo -e " \e[1;31m[stop]\e[0m"
  	exit
}

for OPT_CONF in "${OPT_CONFS[@]}"; do

	if [[ ! -f "${PWD}/.remote/${OPT_CONF}" ]]; then
		echowarn "Conf ${OPT_CONF} doesn't exist!"
		continue
	fi

	exec < "${PWD}/.remote/${OPT_CONF}"

	while read SITE_NAME SITE_URL SITE_EXTRA; do
		[[ -z $SITE_NAME ]] && continue
		if [[ $SITE_NAME == \#* ]]; then
			echodebug "Skipping comment line $SITE_NAME"
			continue
		fi

		if [[ ${#OPT_SITES[@]} > 0 ]] && ! array_contains "$SITE_NAME" "${OPT_SITES[@]}" ; then
			echodebug "Skipping unselected $SITE_NAME"
			continue
		fi
		
		if [[ ${OPT_CONF} == live ]]; then
			i="\e[1;37m${SITE_NAME}\e[0m (\e[1;31m${OPT_CONF}\e[0m)"
		else
			i="\e[1;37m${SITE_NAME}\e[0m (${OPT_CONF})"
		fi

		[[ $OPT_QUIET != yes ]] && echo -en "$i"
		
		if [[ $OPT_INTERACTIVE == yes ]]; then
			echo -en " ["
			echo -en "\e[1mCTRL-C\e[0m to stop, "
			echo -en "\e[1mES\e[0mC|\e[1mn\e[0m to skip, "
			echo -en "\e[1mENTER\e[0m|\e[1my\e[0m to execute, "
			echo -en "\e[1ma\e[0m to execute always"
			echo -en "]"
			trap ctrl_c_trap SIGINT
			while read -r -s -N1 0<&6; do
				case "$REPLY" in $'\x1B'|$'\x0A'|y|Y|n|N|a|A) break ;; esac
			done
			trap - SIGINT
			case "$REPLY" in
				$'\x1B'|n|N)
					echo -e " \e[0;31m[skip]\e[0m"
					continue
					;;
				$'\x0A'|y|Y)
					echo -e " \e[0;32m[execute]\e[0m"
					;;
				a|A)
					echo -e " \e[1;32m[always]\e[0m"
					unset OPT_INTERACTIVE
					;;
			esac
		else
			[[ $OPT_QUIET != yes ]] && echo -en "\n"
		fi

		if [[ $# == 0 ]]; then
			echotrace "remote_exec_i '$SITE_URL'"
			remote_exec_i "$SITE_URL" 0<&6
		else
			echotrace "echo '$@' | remote_exec '$SITE_URL'"
			echo "eval \"$@\";" | remote_exec "$SITE_URL"
		fi
	done
done

exec 0<&6 6<&- # restore stdin
echoinfo "Finished."


