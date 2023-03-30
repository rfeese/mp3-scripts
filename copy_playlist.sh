#!/bin/bash

# TODO: option to randomize playlist dirs

usage() { 
	echo "Usage: $0 [OPTIONS] src_playlist src_base_dir dest_dir"
	echo "OPTIONS:"
	echo "	-h	help"
	echo "	-l	(sym)link to src instead of copy"
	echo "	-r	randomize/shuffle playlist"
	echo "	-d	dry-run - don't do anything"
	echo "	-v	verbose"
	echo "	-V	more verbose"
}

o_symlinks=0
o_randomize=0
o_dryrun=0
o_verbose=0
while getopts "hblrdvV" opts; do
	case "${opts}" in
		h)
			usage
			exit 1
			;;
		l)
			# use symlinks
			o_symlinks=1
			;;
		r)
			o_randomize=1
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
	esac
done

SRC_PLS=""
DEST_DIR=""

SRC_PLS=${@:$OPTIND:1}
SRC_BASE_DIR=${@:$OPTIND+1:1}
DEST_DIR=${@:$OPTIND+2:1}

if [ -z $SRC_PLS ] || [ -z $SRC_BASE_DIR ] || [ -z $DEST_DIR ]; then
	usage
	exit 0
fi

if [ ! -f $SRC_PLS ]; then
	echo "ERROR: src_pls $SRC_PLS does not exist." >&2
	exit 0
fi

if [ ! -d $SRC_BASE_DIR ]; then
	echo "ERROR: src_base_dir does not exist." >&2
	exit 0
fi

if [ ! -d $DEST_DIR ]; then
	echo "creating: $DEST_DIR"
	if [ $o_dryrun == 0 ]; then
		mkdir -p $DEST_DIR
	fi
fi

if [ $o_randomize == 1 ]; then
	rand_pls=$(mktemp /tmp/copy_playlist_rand_pls.XXXXXXXX)
	shuf "${SRC_PLS}" > "${rand_pls}"
	SRC_PLS="${rand_pls}"
fi

track_num=1
while IFS= read -r song; do

	# resolve file path from playlist and src_base_dir
	file="${SRC_BASE_DIR}/${song}"

	if [ ! -f "${file}" ]; then
		echo "ERROR: src_file $file not found." >&2
		continue
	fi

	# check whether file has id3 tag
	mp3info -p "%a / %l / %t\n"  "$file" > /dev/null
	if [ $? -ne 0 ]; then
		echo "ERROR: $file missing ID3 tag." >&2
		continue
	fi

	ARTIST=$(mp3info -p "%a" "$file")
	if [ -z "${ARTIST}" ]; then
		echo "ERROR: $file artist empty." >&2
		continue
	fi

	TRACK_TITLE=$(mp3info -p "%t" "$file")
	if [ -z "${TRACK_TITLE}" ]; then
		echo "ERROR: $file track title empty." >&2
		continue
	fi

	ARTIST_SAFE=$(echo "${ARTIST}" | sed -r "s/[ &/]+/_/g" | sed -r "s/[^0-9A-Za-z._-]+//g")
	ALBUM_SAFE=$(echo "${ALBUM}" | sed -r "s/[ &/]+/_/g" | sed -r "s/[^0-9A-Za-z._-]+//g")
	TRACK_TITLE_SAFE=$(echo "${TRACK_TITLE}" | sed -r "s/[ &/]+/_/g" | sed -r "s/[^0-9A-Za-z._-]+//g")

	# copy the file
	TRACK_NUM_PART=$(printf "%04d_" $track_num)
	dest_file=${DEST_DIR}/${TRACK_NUM_PART}_${ARTIST_SAFE}_-_${TRACK_TITLE_SAFE}.mp3

	# echo "copyto: ${dest_file}"
	if [ ! -f "$dest_file" ]; then
		if [ $o_symlinks == 1 ]; then
			if [ $o_verbose -gt 1 ]; then
				echo "linking $dest_file"
			fi
			if [ $o_dryrun == 0 ]; then
				ln -s "$file" "$dest_file"
			fi
		else
			if [ $o_verbose -gt 1 ]; then
				echo "copying $dest_file"
			fi
			if [ $o_dryrun == 0 ]; then
				cp "$file" "$dest_file"
			fi
		fi

		let track_num++
	fi
done < "${SRC_PLS}"

# clean up random temp file
if [ $o_randomize == 1 ]; then
	rm $rand_pls
fi

exit 1
