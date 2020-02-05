[[ -n $LIBREMOTE_WP_VERSION ]] && return
declare -i -r LIBREMOTE_WP_VERSION=1

DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd -P)"
source "$DIR/libremote.bash"

export_db() {
	local SITE_URL="$1"
	{
		cat <<- EOF
		sql_filter() {
			while read -r; do case "\$REPLY" in "-- MySQL dump"*) echo "\$REPLY"; exec cat; ;; esac; done;
		}
		wp db export - --allow-root | sql_filter | gzip -c
		EOF
	} | remote_exec "${SITE_URL}"
}

import_db() {
	local SITE_URL="$1"
	{
		cat <<- EOF
		sql_skip_definer() {
			sed 's%^/\*!50013 DEFINER=.*$%%'
		}
		wp db reset --yes --allow-root < /dev/null
		gzip -d -c | sql_skip_definer | wp db import - --allow-root
		EOF
		cat
	} | remote_exec "${SITE_URL}"
}

load_site_info_wp() {
	local CONF_FILE="$1"
	local SITE_NAME_REQ="$2"
	local PREFIX="$3"
	
	local TMP_SITE_NAME
	local TMP_SITE_URL
	local TMP_EXTRA1
	local TMP_EXTRA2
	local TMP_EXTRA3
	local TMP_EXTRA4
	local TMP_EXTRA5
	
	local TMP_SSH_DEST
	local TMP_SITE_DIR
	local TMP_DOCKER
	
	eval "$(load_site_info "$CONF_FILE" "$SITE_NAME_REQ" "local TMP_")"

	eval "$(parse_site_url "$TMP_SITE_URL" "local TMP_")"

	if [[ -z $TMP_EXTRA1 ]]; then
		TMP_EXTRA1="http://www.example.com"
	fi
	if [[ -z $TMP_EXTRA2 ]]; then
		TMP_EXTRA2="${TMP_SITE_DIR}/wp-content/uploads"
	fi

	cat <<- EOF
	${PREFIX}SITE_NAME='$TMP_SITE_NAME'
	${PREFIX}SITE_URL='$TMP_SITE_URL'
	${PREFIX}EXTRA1='$TMP_EXTRA1'   
	${PREFIX}EXTRA2='$TMP_EXTRA2'   
	${PREFIX}EXTRA3='$TMP_EXTRA3'   
	${PREFIX}EXTRA4='$TMP_EXTRA4'   
	${PREFIX}EXTRA5='$TMP_EXTRA5'   
	${PREFIX}SSH_DEST='$TMP_SSH_DEST'
	${PREFIX}SITE_DIR='$TMP_SITE_DIR'
	${PREFIX}DOCKER='$TMP_DOCKER'
	${PREFIX}SITE_WEBURL='$TMP_EXTRA1'
	${PREFIX}SITE_UPLOADS='$TMP_EXTRA2'
	EOF
}

live_plugins=(
	cloudflare
	google-captcha
	sucuri-scanner
	w3-total-cache
	wordpress-seo
	wordpress-seo-premium
	wp-hummingbird
	wpmudev-updates
	wpseo-news
	wp-smush-pro
	wp-super-cache
)

deactivate_live_plugins() {
	local SITE_URL="$1"
	{
		cat <<- EOF
		wp plugin deactivate ${live_plugins[@]}
		EOF
	} | remote_exec "${SITE_URL}"
}

replace_text_in_db() {
	local SITE_URL="$1"
	local SRC="$2"
	local DST="$3" 
	{
		cat <<- EOF
		wp search-replace "$SRC" "$DST"
		EOF
	} | remote_exec "${SITE_URL}"
}

# vim:set ft=sh:
