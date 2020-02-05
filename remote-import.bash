#/bin/bash

DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd -P)"
NAME="${0##*/}"

[[ -z $LOGLEVEL ]] && LOGLEVEL=4
source "${DIR}/libloglevel.bash"
source "${DIR}/libremote_wp.bash"

OPT_FORCE=no
OPT_DEACTIVATE=no
OPT_SRCSITE=
OPT_SRCCONF="live"
OPT_DSTSITE=
OPT_DSTCONF="local"

while [ $# -gt 0 ]; do
	case "$1" in
		-c|--src-conf)
			shift
			OPT_SRCCONF="${1##*/}"
			shift
			;;
		-c2|--dst-conf)
			shift
			OPT_DSTCONF="${1##*/}"
			shift
			;;
		-s|--src-site)
			shift
			OPT_SRCSITE="${1}"
			shift
			;;
		-s2|--dst-site)
			shift
			OPT_DSTSITE="${1}"
			shift
			;;
		-f|--force)
			shift
			OPT_FORCE=yes
			;;
		-d|--deactivate)
			shift
			OPT_DEACTIVATE=yes
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

exec 3>&2
LOGSINK='1>&3' generate_logfunctions
exec >  >(LOGDOMAIN=stdout loginfo)
exec 2> >(LOGDOMAIN=stderr logwarn)

if [[ -z $OPT_DSTSITE ]]; then
	OPT_DSTSITE="$OPT_SRCSITE"
fi

CONF_DIR="$(find_conf_dir "$PWD")"
if [[ ! -d ${CONF_DIR} ]]; then
	echoerr "Conf directory not found!"
	exit 1
fi

echodebug "Loading source site '$OPT_SRCSITE' info from '${CONF_DIR}/${OPT_SRCCONF}'."
eval "$(load_site_info_wp "${CONF_DIR}/${OPT_SRCCONF}" "$OPT_SRCSITE" "SRC_")"
	
if [[ -z $SRC_SITE_URL ]]; then
	echoerr "Site source site not specified!"
	exit 1
fi

echodebug "Loading destination site '$OPT_DSTSITE' info from '${CONF_DIR}/${OPT_DSTCONF}'."
eval "$(load_site_info_wp "${CONF_DIR}/${OPT_DSTCONF}" "$OPT_DSTSITE" "DST_")"

if [[ -z $DST_SITE_URL ]]; then
	echoerr "Site destination site not specified!"
	exit 1
fi

CACHEDIR="${CONF_DIR}/../.remote-backup"
BACKUP="$CACHEDIR/${OPT_SRCCONF}-${OPT_SRCSITE}.sql.gz"
if [[ ! -f $BACKUP || $OPT_FORCE == yes ]]; then
	echoinfo "Exporting db ${OPT_SRCCONF}/${OPT_SRCSITE}."
	mkdir -p "$CACHEDIR"
	export_db "$SRC_SITE_URL" > "$BACKUP"
fi

echoinfo "Importing into db ${OPT_DSTCONF}/${OPT_DSTSITE}."
cat "$BACKUP" | import_db "$DST_SITE_URL"

echoinfo "Replacing '$SRC_SITE_WEBURL' -> '$DST_SITE_WEBURL'."
replace_text_in_db "${DST_SITE_URL}" "$SRC_SITE_WEBURL" "$DST_SITE_WEBURL"

if [[ $OPT_DEACTIVATE == yes ]]; then
	echoinfo "Deactivating unwanted plugins."
	deactivate_live_plugins "${DST_SITE_URL}"
fi
echoinfo "Finished."


