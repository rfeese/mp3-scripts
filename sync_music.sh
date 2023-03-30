usage() { 
	echo "Usage: $0 [OPTIONS] src_dir dest_dir"
	echo "OPTIONS:"
	echo "	-h	help"
	echo "	-l	(sym)link alternates instead of copy"
	echo "	-d	dry-run - don't do anything"
	echo "	-v	verbose"
	echo "	-V	more verbose"
}

o_symlinks=0
o_dryrun=0
o_verbose=0
o_randomize_playlists=0
# options passed to sub-scripts
o_l=''
o_d=''
o_v=''
o_V=''
while getopts "hldvV" opts; do
	case "${opts}" in
		h)
			usage
			exit 1
			;;

		l)
			# use symlinks
			o_symlinks=1
			o_l=' -l'
			;;

		d)
			# dryrun
			o_dryrun=1
			o_d=' -d'
			;;

		v)
			# verbose
			o_verbose=1
			o_v=' -v'
			;;

		V)
			# verbose
			o_verbose=2
			o_V=' -V'
			;;

		r)
			# randomize
			o_randomize=1
			;;

	esac
done

SRC_DIR=""
DEST_DIR=""

SRC_DIR=${@:$OPTIND:1}
DEST_DIR=${@:$OPTIND+1:1}

if [ -z $SRC_DIR ] || [ -z $DEST_DIR ]; then
	usage
	exit 0
fi

if [ ! -d $SRC_DIR ]; then
	echo "ERROR: src_dir does not exist." 1>&2
	exit 0
fi

if [ ! -d $DEST_DIR ]; then
	echo "ERROR: dest_dir does not exist." 1>&2
	exit 0
fi


# sync Artist-Album
if [ ! -d $SRC_DIR/Artist-Album ]; then
	echo "ERROR: src_dir/Artist-Album does not exist." 1>&2
	exit 0
fi
if [ ! -d $DEST_DIR/Artist-Album ]; then
	echo "ERROR: dest_dir/Artist-Album does not exist." 1>&2
	exit 0
fi

if [ $o_dryrun == 1 ]; then
	newfiles=$(rsync -av --size-only --out-format='%i#%n' --dry-run ${SRC_DIR}/Artist-Album/ ${DEST_DIR}/Artist-Album/ | grep '^>f' | cut -d '#' -f2)
else
	newfiles=$(rsync -av --size-only --out-format='%i#%n' ${SRC_DIR}/Artist-Album/ ${DEST_DIR}/Artist-Album/ | grep '^>f' | cut -d '#' -f2)
fi

if [ $o_verbose -gt 0 ]; then
	echo "$(echo $newfiles | wc -w) new files."
fi

# update Artist
# TODO: what if some went away?
if [ ! -d $DEST_DIR/Artist ]; then
	echo "ERROR: dest_dir/Artist does not exist." 1>&2
	exit 0
fi
for file in $newfiles
do
	./copy_mp3s.sh${o_l}${o_d}${o_v}${o_V} -t "${SRC_DIR}/Artist-Album/${file}" ${DEST_DIR}/Artist
done

# update Playlists
if [ ! -d $DEST_DIR/Playlists ]; then
	echo "ERROR: dest_dir/Playlists does not exist." 1>&2
	exit 0
fi
for playlist_file in $SRC_DIR/Playlists/
do
	dest_playlist=$DEST_DIR/Playlists/${playlist_file%%.*}
	# clear out old playlist
	if [ -d $dest_playlist ]; then
		rm $dest_playlist/*
	fi

	if [ $o_randomize == 1 ]; then
		./copy_playlist.sh${o_l}${o_d}${o_v}${o_V} -r $playlist_file $DEST_DIR/Artist-Album $dest_playlist
	else
		./copy_playlist.sh${o_l}${o_d}${o_v}${o_V} $playlist_file $DEST_DIR/Artist-Album $dest_playlist
	fi
done
