
DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd -P)"

ssh_wrapper() {
	[[ -d $HOME/.ssh/ctl/ ]] || mkdir -p "$HOME/.ssh/ctl"
	/usr/bin/ssh -x -C -S "$HOME/.ssh/ctl/%r@%h:%p" -o ControlMaster=auto -o ControlPersist=10 "$@"
}


parse_site_url() {
	local URL="$1"
	local PREFIX="$2"
	local TMP_SSH_DEST TMP_SITE_DIR TMP_DOCKER

	case "$URL" in
		"ssh://"*)
			TMP_SSH_DEST="${URL#ssh://}"
			TMP_SSH_DEST="${TMP_SSH_DEST%%/*}"
			TMP_SITE_DIR="${URL#ssh://}/"
			TMP_SITE_DIR="${TMP_SITE_DIR#*/}"
			TMP_SITE_DIR="${TMP_SITE_DIR%/}"
			case "$TMP_SITE_DIR" in
				"docker://"*)
					TMP_DOCKER="${TMP_SITE_DIR#docker://}"
					TMP_DOCKER="${TMP_DOCKER%%/*}"
					TMP_SITE_DIR="${TMP_SITE_DIR#docker://}"
					TMP_SITE_DIR="/${TMP_SITE_DIR#*/}"
					;;
			esac
			case "$TMP_SITE_DIR" in
				"~/"*)
					TMP_SITE_DIR="${TMP_SITE_DIR#\~/}"
					;;
				"./"*)
					TMP_SITE_DIR="${TMP_SITE_DIR#./}"
					;;
				"")
					TMP_SITE_DIR="."
					;;
				"/"*)
					;;
				*)
					TMP_SITE_DIR="/$TMP_SITE_DIR"
					;;
			esac
			;;
		*)
			TMP_SITE_DIR="$URL"
	esac

	cat <<- EOF
	${PREFIX}SSH_DEST='$TMP_SSH_DEST'
	${PREFIX}SITE_DIR='$TMP_SITE_DIR'
	${PREFIX}DOCKER='$TMP_DOCKER'
	EOF
}


remote_exec() {
	local SITE_URL="$1"
	local SSH_DEST SITE_DIR DOCKER
	eval "$(parse_site_url "$SITE_URL")"
	if [[ -z $SSH_DEST ]]; then
		/bin/bash -c "cd '${SITE_DIR}'; exec /bin/bash;"
	elif [[ -z $DOCKER ]]; then
		ssh_wrapper "${SSH_DEST}" -- "exec /bin/bash -c \"cd '${SITE_DIR}'; exec /bin/bash;\""
	else
		ssh_wrapper "${SSH_DEST}" -- "exec docker exec -i "${DOCKER}" /bin/bash -c \"cd '${SITE_DIR}'; exec /bin/bash;\""
	fi
}


remote_exec_i() {
	local SITE_URL="$1"
	local SSH_DEST SITE_DIR DOCKER
	eval "$(parse_site_url "$SITE_URL")"
	if [[ -z $SSH_DEST ]]; then
		/bin/bash -c "cd '${SITE_DIR}'; exec /bin/bash -i;"
	elif [[ -z $DOCKER ]]; then
		ssh_wrapper -tt "${SSH_DEST}" -- "exec /bin/bash -i -c \"cd '${SITE_DIR}'; exec /bin/bash -i;\""
	else
		ssh_wrapper -tt "${SSH_DEST}" -- "exec docker exec --privileged -i -t '${DOCKER}' /bin/bash -i -c \"cd '${SITE_DIR}'; export COLUMNS=\$(tput cols); export LINES=\$(tput lines); exec /bin/bash -i;\""
	fi
}


array_contains() {
	local i match="$1"
	shift
	for i; do [[ $i == $match ]] && return 0; done
	return 1
}


load_site_info() {
	local CONF_FILE="$1"
	local SITE_NAME_REQ="$2"
	local PREFIX="$3"
	local TMP_SITE_NAME TMP_SITE_URL TMP_EXTRA TMP_EXTRA1 TMP_EXTRA2 TMP_EXTRA3 TMP_EXTRA4 TMP_EXTRA5 
	while read TMP_SITE_NAME TMP_SITE_URL TMP_EXTRA1 TMP_EXTRA2 TMP_EXTRA3 TMP_EXTRA4 TMP_EXTRA5; do
		[[ -z $TMP_SITE_NAME ]] && continue
		[[ $TMP_SITE_NAME == \#* ]] && continue
		[[ $TMP_SITE_NAME == $SITE_NAME_REQ ]] && break
	done < "${CONF_FILE}"
	
	cat <<- EOF
	${PREFIX}SITE_NAME='$TMP_SITE_NAME'
	${PREFIX}SITE_URL='$TMP_SITE_URL'
	${PREFIX}EXTRA1='$TMP_EXTRA1'
	${PREFIX}EXTRA2='$TMP_EXTRA2'
	${PREFIX}EXTRA3='$TMP_EXTRA3'
	${PREFIX}EXTRA4='$TMP_EXTRA4'
	${PREFIX}EXTRA5='$TMP_EXTRA5'
	EOF
}

