#!/bin/bash

usage() { 
	echo "Usage: $0 [OPTIONS] src dest_dir"
	echo "OPTIONS:"
	echo "	-h	help"
	echo "	-b	album directories"
	echo "	-l	(sym)link to src instead of copy"
	echo "	-d	dry-run - don't do anything"
	echo "	-v	verbose"
	echo "	-V	more verbose"
	echo "	-t	trust variation"
}

o_album_dirs=0
o_symlinks=0
o_dryrun=0
o_verbose=0
o_trust_variations=0
while getopts "hbldvVt" opts; do
	case "${opts}" in
		h)
			usage
			exit 1
			;;

		b)
			# do album dirs
			o_album_dirs=1
			;;

		l)
			# use symlinks
			o_symlinks=1
			;;

		d)
			# dryrun
			o_dryrun=1
			;;

		v)
			# verbose
			o_verbose=1
			;;

		V)
			# verbose
			o_verbose=2
			;;

		t)
			# trust variations
			o_trust_variations=1
			;;
	esac
done

SRC=""
DEST_DIR=""

SRC=${@:$OPTIND:1}
DEST_DIR=${@:$OPTIND+1:1}

if [ -z $SRC ] || [ -z $DEST_DIR ]; then
	usage
	exit 0
fi

if [[ (! -d $SRC) && (! -f $SRC) ]]; then
	echo "ERROR: src does not exist." 1>&2
	exit 0
fi

if [ ! -d $DEST_DIR ]; then
	echo "ERROR: dest_dir does not exist." 1>&2
	exit 0
fi


copy_file() {
	file=$1

	# check whether file has id3 tag
	mp3info -p "%a / %l / %t\n"  "$file" > /dev/null
	if [ $? -ne 0 ]; then
		echo "ERROR: $file missing ID3 tag." 1>&2
		continue
	fi

	ARTIST=$(mp3info -p "%a" "$file")
	if [ -z "${ARTIST}" ]; then
		echo "ERROR: $file artist empty." 1>&2
		continue
	fi

	# allow empty album
	ALBUM=$(mp3info -p "%l" "$file")
#	if [ -z "${ALBUM}" ]; then
#		echo "Warning: $file album empty."
#	fi

	TRACK_NUM=$(mp3info -p "%n" "$file")
	TRACK_NUM_PART=""
	if [ ! -z "${TRACK_NUM}" ]; then
		TRACK_NUM_PART=$(printf "%02d_" $TRACK_NUM)
	fi

	TRACK_TITLE=$(mp3info -p "%t" "$file")
	if [ -z "${TRACK_TITLE}" ]; then
		echo "ERROR: $file track title empty." 1>&2
		continue
	fi

	ARTIST_SAFE=$(echo "${ARTIST}" | sed -r "s/[ &/]+/_/g" | sed -r "s/[^0-9A-Za-z._-]+//g")
	ALBUM_SAFE=$(echo "${ALBUM}" | sed -r "s/[ &/]+/_/g" | sed -r "s/[^0-9A-Za-z._-]+//g")
	TRACK_TITLE_SAFE=$(echo "${TRACK_TITLE}" | sed -r "s/[ &/]+/_/g" | sed -r "s/[^0-9A-Za-z._-]+//g")

	# artist first letter dir
	A_LETTER=${ARTIST_SAFE:0:1}
	digit='^[0-9]$'
	if [[ $A_LETTER =~ $digit ]]; then
		A_LETTER='0-9'
	fi

	# echo $A_LETTER / $ARTIST_SAFE / $ALBUM_SAFE / $TRACK_NUM_PART$TRACK_TITLE_SAFE
	# continue
	
	if [ ! -d $DEST_DIR/$A_LETTER ]; then
		if [ ${o_verbose} -gt 0 ]; then
			echo "creating: $DEST_DIR/$A_LETTER"
		fi
		if [ $o_dryrun == 0 ]; then
			mkdir $DEST_DIR/$A_LETTER
		fi
	fi

	# look for variations on Artist the
	if [ $(find $DEST_DIR/T/ -maxdepth 1  -mindepth 1 -type d -iname "The_$ARTIST_SAFE" | wc -l) -gt 0 ]; then
		altartistdir=$(find $DEST_DIR/T/ -maxdepth 1 -mindepth 1 -type d -iname "The_$ARTIST_SAFE" -printf '%P')
		echo "Warning: artist-name 'the' variation exists for $ARTIST_SAFE: $altartistdir" 1>&2
		if [ ${o_trust_variations} == 1 ]; then
			ARTIST="The $ARTIST"
			ARTIST="${ARTIST:0:30}"
			A_LETTER='T'
			ARTIST_SAFE=$altartistdir
		fi
	fi

	# look for variation of Artist &/and
	if [[ $ARTIST == *\&* ]]; then
		artistand=${ARTIST/\&/and}
		artistand=$(echo "${artistand}" | sed -r "s/[ &/]+/_/g" | sed -r "s/[^0-9A-Za-z._-]+//g")
		# shorten
		artistand="${artistand:0:30}"
		#echo "Looking for artist and variation: $artistand ..."
		if [ $(find $DEST_DIR/$A_LETTER/ -maxdepth 1 -mindepth 1 -type d -iname "$artistand" | wc -l) -gt 0 ]; then
			altartistdir=$(find $DEST_DIR/$A_LETTER/ -maxdepth 1 -mindepth 1 -type d -iname "$artistand" -printf '%P')
			echo "Warning: artist-name 'and' variation exists for $ARTIST_SAFE: $altartistdir" 1>&2
			if [ ${o_trust_variations} == 1 ]; then
				ARTIST=${ARTIST/\&/and}
				ARTIST="${ARTIST:0:30}"
				ARTIST_SAFE=$altartistdir
			fi
		fi
	fi

	# look for variations on Artist case insensitive
	if [ ! -d $DEST_DIR/$A_LETTER/$ARTIST_SAFE ]; then
		if [ $(find $DEST_DIR/$A_LETTER/ -maxdepth 1 -mindepth 1 -type d -iname "$ARTIST_SAFE" | wc -l) -gt 0 ]; then
			altartistdir=$(find $DEST_DIR/$A_LETTER/ -maxdepth 1 -mindepth 1 -type d -iname "$ARTIST_SAFE" -printf '%P')
			echo "Warning: artist-name captialization variation exists for $ARTIST_SAFE: $altartistdir" 1>&2
			if [ ${o_trust_variations} == 1 ]; then
				ARTIST_SAFE=$altartistdir
			fi
		fi
	fi

	# artist dir
	if [ ! -d $DEST_DIR/$A_LETTER/$ARTIST_SAFE ]; then
		if [ ${o_verbose} -gt 0 ]; then
			echo "creating: $DEST_DIR/$A_LETTER/$ARTIST_SAFE"
		fi
		if [ $o_dryrun == 0 ]; then
			mkdir $DEST_DIR/$A_LETTER/$ARTIST_SAFE
		fi
	fi

	# look for variation of album &/and
	if [[ (${o_album_dirs} == 1 ) && ($ALBUM == *\&*) ]]; then
		if [ -d $DEST_DIR/$A_LETTER/$ARTIST_SAFE ]; then
			albumand=${ALBUM/\&/and}
			albumand=$(echo "${albumand}" | sed -r "s/[ &/]+/_/g" | sed -r "s/[^0-9A-Za-z._-]+//g")
			# shorten
			albumand="${albumand:0:30}"
			if [ $(find $DEST_DIR/$A_LETTER/$ARTIST_SAFE/ -maxdepth 1 -mindepth 1 -type d -iname "$albumand" | wc -l) -gt 0 ]; then
				# echo "looking for albumdir $DEST_DIR/$A_LETTER/$ARTIST_SAFE/$albumand ..."
				altalbumdir=$(find $DEST_DIR/$A_LETTER/$ARTIST_SAFE/ -maxdepth 1 -mindepth 1 -type d -iname "$albumand" -printf '%P')
				echo "Warning: album-name 'and' variation exists for $ARTIST_SAFE/$ALBUM_SAFE: $altalbumdir" 1>&2
				if [ ${o_trust_variations} == 1 ]; then
					ALBUM_SAFE=$altalbumdir
				fi
			fi
		fi
	fi

	if [[ (${o_album_dirs} == 1 ) && (-d $DEST_DIR/$A_LETTER/$ARTIST_SAFE) ]]; then
		# look for variations on Album case insensitive
		if [[ ! -d $DEST_DIR/$A_LETTER/$ARTIST_SAFE/$ALBUM_SAFE ]]; then
			if [ $(find $DEST_DIR/$A_LETTER/$ARTIST_SAFE/ -maxdepth 1 -mindepth 1 -type d -iname "$ALBUM_SAFE" | wc -l) -gt 0 ]; then
				altalbumdir=$(find $DEST_DIR/$A_LETTER/$ARTIST_SAFE -maxdepth 1 -mindepth 1 -type d -iname "$ALBUM_SAFE" -printf '%P')
				echo "Warning: album-name captialization variation exists for $ARTIST_SAFE/$ALBUM_SAFE: $altalbumdir" 1>&2
				if [ ${o_trust_variations} == 1 ]; then
					ALBUM_SAFE=$altalbumdir
				fi
			fi
		fi
		# look for variations on Album the
		if [ $(find $DEST_DIR/$A_LETTER/$ARTIST_SAFE -maxdepth 1 -mindepth 1 -type d -iname "The_$ALBUM_SAFE" | wc -l) -gt 0 ]; then
			altalbumdir=$(find $DEST_DIR/$A_LETTER/$ARTIST_SAFE -maxdepth 1 -mindepth 1 -type d -iname "The_$ALBUM_SAFE" -printf '%P')
			echo "Warning: album-name 'the' variation exists for $ARTIST_SAFE/$ALBUM_SAFE: $altalbumdir" 1>&2
			if [ ${o_trust_variations} == 1 ]; then
				ALBUM_SAFE=$altalbumdir
			fi
		fi
	fi

	# album dir
	if [[ (${o_album_dirs} == 1 ) && ( ! -z ${ALBUM_SAFE} ) ]]; then
		if [[ ! -d $DEST_DIR/$A_LETTER/$ARTIST_SAFE/$ALBUM_SAFE ]]; then
			if [ ${o_verbose} -gt 0 ]; then
				echo "creating: $DEST_DIR/$A_LETTER/$ARTIST_SAFE/$ALBUM_SAFE"
			fi
			if [ $o_dryrun == 0 ]; then
				mkdir $DEST_DIR/$A_LETTER/$ARTIST_SAFE/$ALBUM_SAFE
			fi
		else
			if [ ${o_verbose} == 2 ]; then
				echo "album dir already exists: $DEST_DIR/$A_LETTER/$ARTIST_SAFE/$ALBUM_SAFE"
			fi

		fi
	fi

	# copy the file
	if [[ ${o_album_dirs} == 1 ]]; then
		if [ -z ${ALBUM_SAFE} ]; then
			dest_file=${DEST_DIR}/${A_LETTER}/${ARTIST_SAFE}/${TRACK_TITLE_SAFE}.mp3
		else
			dest_file=${DEST_DIR}/${A_LETTER}/${ARTIST_SAFE}/${ALBUM_SAFE}/${TRACK_NUM_PART}${TRACK_TITLE_SAFE}.mp3
		fi
	else # not making album dirs
		dest_file=${DEST_DIR}/${A_LETTER}/${ARTIST_SAFE}/${TRACK_TITLE_SAFE}.mp3

		# if file exitsts (same song, different album) generate a different name (based on album)
		if [ -f "$dest_file" ]; then
			if [[ ${o_verbose} -gt 0 && -z ${ALBUM_SAFE} ]]; then
				echo "creating alternate: ${DEST_DIR}/${A_LETTER}/${ARTIST_SAFE}/${TRACK_TITLE_SAFE}_${ALBUM_SAFE}.mp3"
			fi
			dest_file=${DEST_DIR}/${A_LETTER}/${ARTIST_SAFE}/${TRACK_TITLE_SAFE}_${ALBUM_SAFE}.mp3
		fi
	fi

	# echo "copyto: ${dest_file}"
	if [ ! -f "$dest_file" ]; then
		if [ ${o_verbose} == 2 ]; then
			echo "copying to: $dest_file"
		fi
		if [ $o_dryrun == 0 ]; then
			if [ $o_symlinks == 1 ]; then
				ln -s "$file" "$dest_file"
			else
				cp "$file" "$dest_file"
			fi
		fi
	else
		if [ ${o_verbose} == 2 ]; then
			echo "alreaty exists: $dest_file"
		fi
	fi
}

# if src is a file, copy one file
if [ -f $SRC ]; then
	copy_file $SRC
# look for files in a directory
else
	# enable globbing to search subdirs
	shopt -s globstar
	for file in $SRC/**/*.mp3
	do
		copy_file $file
	done
fi
exit 1
