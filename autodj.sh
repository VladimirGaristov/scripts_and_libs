#!/bin/bash

# AutoDJ v2.1 - download a song and add it to a queue in Mixxx
# Copyright (C) 2021 Vladimir Garistov <vl.garistov@gmail.com>
#
# This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program; if not, write to the
# Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

# This script reads a song name from standard input, searches for it on YouTube, downloads only the audio from the
# first result and adds it to the AutoDJ queue in Mixxx.
#
# The script relies on hard-coded coordinates on which it clicks. You must configure these coordinates
# based on your monitor. Obviously changing the window size of Mixxx in any way will interfere with the correct
# operation of this script. It is recomended to leave Mixxx in fullscreen on the primary display.
#
# It is recommended to clear the AutoDJ queue after starting the script. Add at least two songs before starting
# the AutoDJ function in Mixxx to avoid playing the first song twice. 
#
# Known issues:
# -very long song names that only differ in the last parts of their names can be mistaken for each other
#
# Version 1.0 uses VLC instead of Mixxx and is simpler, more reliable and more lightweight. However, VLC does not
# support crossfading between songs and doesn't have the AutoDJ functionality that Mixxx has.

# Set the directory where AutoDJ will download all songs. It must be the Mixxx library or preferably a folder in it.
# No trailing slash!
download_location='/home/cartogan/Music/autodj'
buffer_dir='/var/tmp/autodj/buffer'
# Time in ms to wait after reloading Mixxx music library
mixxx_lib_reload_time=500
# Time in ms to wait between two clicks to avoid them being detected as a doubleckick
click_delay_time=500

# No, neither xdo nor xdotool works reliably for getting the PID of the parent terminal emulator
autodj_pid=$(ps -o ppid= -p $(ps -o ppid= -p $$) | awk '{$1=$1;print}')

mkdir -p /var/tmp/autodj
mkdir -p /var/tmp/autodj/buffer
rm /var/tmp/autodj/buffer/* >/dev/null 2>&1

mixxx >/dev/null 2>&1 &
mixxx_pid=$!
sleep 3

# Unicode symbols in video titles are escaped as bytes which are represented with \x notation
# For example the cyrilic letter "Щ" (sht) becomes "\xd0\xa9" - 8 bytes in total
# The maximum filename lenght on most filesystems, including ext4, is 255 bytes
# The filename during download ends in .webm.part (10 bytes) and \0 (I think?)
# This suggests that the maximum title lenght if only cyrillic letters are used is (255 - 11) / 8 = 30
# In practice the script works fine with titles that include 50+ cyrilic letters but breaks somewhere around 60.
# Needs more testing
# So basically, I got annoyed by this ungodly crap and eyeballed the lenght limit.
max_filename_lenght='60'

song='-'

printf "Vlado Garistov's AutoDJ \nInput q to quit\nDon't forget to clear the queue in Mixxx after starting the script!\n"

# The authentication is needed for age-restricted videos but throws errors. TODO
#printf "\nYouTube username: "
#read user
#printf "\nYouTube password: "
#read -s pass

while [ true ]
do
	# Input song name
	printf "\nRequest a song: "
	read song

	# Input X to exit the script
	if [ "$song" = 'q' ] || [ "$song" = 'Q' ]
	then
		kill $(jobs -p)
		exit 0
	fi
	if [ "$song" = '' ]
	then
		continue
	fi

	# Replace spaces with + in the song name
	song=${song// /+}
	# Download the youtube page with search results for videos with this name
	curl "https://www.youtube.com/results?search_query=$song" > /var/tmp/autodj/yt_results.html

	sed -i -e 's/\"/\n/g' /var/tmp/autodj/yt_results.html
	# Obtain the URL of the first result
	url="https://www.youtube.com$(cat /var/tmp/autodj/yt_results.html | grep '/watch?v=' | head -n 1)"
	echo $url

	if [ "$url" = 'https:://www.youtube.com' ]
	then
		continue
	fi

	# Download only the audio of this video
	yt-dlp -f "m4a" -o "$buffer_dir/%(title).$(echo $max_filename_lenght)s.%(ext)s" --no-playlist $url

	# The new song will be the only file in the directory
	filename="$(ls $buffer_dir)"
	ffmpeg -i "$buffer_dir/$filename" -c:v copy -c:a libmp3lame -q:a 4 "$buffer_dir/${filename//.m4a/.mp3}"
	rm "$buffer_dir/$filename"
	filename="$(ls $buffer_dir)"

	if [ ! -f "$buffer_dir/$filename" ]
	then
		continue
	fi
	existing_copies=$(ls $download_location | grep "${filename//.mp3/''}" | wc -l)

	# Move the file to another directory because youtube-dl sets the timestamps to weird values and
	# it cannot be determined which file is the latest
	if [ $existing_copies -gt 0 ]
	then
		mv "$buffer_dir/$filename" "$download_location/${filename//.mp3/''}-${existing_copies}.mp3"
	else
		mv "$buffer_dir/$filename" "$download_location/$filename"
	fi

	# Add the song to the current playlist
	xdo activate -p $mixxx_pid
	# The coordinates in the next command need to be adjusted according to the location of the 'Tracks',
	# 'AutoDJ' and 'Date Added' buttons in your Mixxx GUI
	# First it refreshes the library, then it clicks the 'Tracks' button, sorts the songs by date added,
	# selects the latest one, adds it to the AutoDJ queue and clicks the 'AutoDJ' button to show the queue.
	# Due to a bug in Mixxx sometimes the sorting gets messed up. That's why the songs must be resorted every time.
	xte "usleep ${mixxx_lib_reload_time}000" 'keydown Alt_L' 'key l' 'keyup Alt_L' 'key Return' "usleep ${mixxx_lib_reload_time}000" 'mousemove 70 590' 'mouseclick 1' 'mousemove 1290 560' 'mouseclick 1' "usleep ${click_delay_time}000" 'mouseclick 1' 'key Down' 'key Menu' 'key Down' 'key Return' 'mousemove 70 610' 'mouseclick 1'
	xdo activate -p $autodj_pid
done
