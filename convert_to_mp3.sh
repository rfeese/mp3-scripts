#!/bin/bash

usage() { 
	echo "Usage: $0 [OPTIONS] src dest_dir"
	echo "OPTIONS:"
	echo "	-h	help"
	echo "	-d	dry-run - don't do anything"
	echo "	-v	verbose"
	echo "	-V	more verbose"
}

o_dryrun=0
o_verbose=0
while getopts "hdvV" opts; do
	case "${opts}" in
		h)
			usage
			exit 1
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

SRC="."
DEST_DIR="."

SRC=${@:$OPTIND:1}
DEST_DIR=${@:$OPTIND+1:1}

if [[ (! -d $SRC) && (! -f $SRC) ]]; then
	echo "ERROR: src $SRC does not exist." 1>&2
	exit 0
fi

if [ ! -d $DEST_DIR ]; then
	echo "ERROR: dest_dir $DEST_DIR does not exist." 1>&2
	exit 0
fi


convert_file_to_mp3() {
	file="$1"
	if [ ${o_verbose} -gt 1 ]; then
		echo "input $file..."
	fi
	extension="${file##*.}"
	basename="$(basename "$file" .$extension)"
	dest_file="${DEST_DIR}/${basename}.mp3"
	if [ ${o_verbose} -gt 0 ]; then
		echo "converting $file to $dest_file ..."
	fi
	if [ $o_dryrun == 0 ]; then
		ffmpeg -hide_banner -loglevel quiet -i "$file" -c:a libmp3lame -ac 2 -q:a 2 "$dest_file"
		# create v1 tag
		eyeD3 -l error -Q --to-v1.1 "$dest_file"
	fi
}


# if src is a file, copy one file
if [ -f $SRC ]; then
	convert_file_to_mp3 "$SRC"
# look for files in a directory
else
	# enable globbing to search subdirs
	shopt -s globstar
	for file in $SRC/*.m4a
	do
		convert_file_to_mp3 "$file"
	done
fi
exit 1
