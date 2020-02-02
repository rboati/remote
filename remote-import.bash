#/bin/bash

DIR="$(cd "$(dirname "$(realpath "$BASH_SOURCE")")" && pwd -P)"
NAME="${0##*/}"

source "${DIR}/remote-wp.bash"
source "${DIR}/loglevel.bash"

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

if [[ -z $OPT_DSTSITE ]]; then
	OPT_DSTSITE="$OPT_SRCSITE"
fi


eval "$(load_site_info_wp "$PWD/.remote/${OPT_SRCCONF}" "$OPT_SRCSITE" "SRC_")"
	
if [[ -z $SRC_SITE_URL ]]; then
	echoerr "Site $OPT_SRCSITE not found in conf $OPT_SRCCONF!"
	exit 1
fi

eval "$(load_site_info_wp "$PWD/.remote/${OPT_DSTCONF}" "$OPT_DSTSITE" "DST_")"

if [[ -z $DST_SITE_URL ]]; then
	echoerr "Site $OPT_DSTSITE not found in conf $OPT_DSTCONF!"
	exit 1
fi

CACHEDIR="$PWD/.remote-backup"
BACKUP="$CACHEDIR/${OPT_SRCCONF}-${OPT_SRCSITE}.sql.gz"
if [[ ! -f $BACKUP || $OPT_FORCE == yes ]]; then
	echo "$NAME: Exporting db ${OPT_SRCCONF}/${OPT_SRCSITE}"
	mkdir -p "$CACHEDIR"
	export_db "$SRC_SITE_URL" > "$BACKUP"
fi

echoinfo "$NAME: Importing into db ${OPT_DSTCONF}/${OPT_DSTSITE}"
cat "$BACKUP" | import_db "$DST_SITE_URL" &

echoinfo "Replacinf"
replace_text_in_db "${DST_SITE_URL}" "$SRC_SITE_WEBURL" "$DST_SITE_WEBURL"

if [[ $OPT_DEACTIVATE == yes ]]; then
	deactivate_live_plugins "${DST_SITE_URL}"
fi



