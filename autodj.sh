#!/bin/bash

# AutoDJ v2.0 - download a song and add it to a queue in Mixxx
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
# first result and adds it to the AutoDJ queue in Mixxx. It relies on Mixxx being configured to automatically
# add as many songs to the AutoDJ queue as it finds in the Music library. This is achieved by setting the
# following in ~/.mixxx/mixxx.cfg :
# [Auto DJ]
# EnableRandomQueue 1
# EnableRandomQueueBuff 1
# RandomQueueMinimumAllowed 1000
# RandomQueueMinimumAllowedBuff 1000
# Requeue 0
#
# The script also relies on hard-coded coordinates from which it reads the next song in the Mixxx queue. It does
# so by taking a screenshot of the Mixxx GUI and passing it through OCR. You must configure these coordinates
# based on your monitor. Obviously changing the window size of Mixxx in any way will interfere with the correct
# operation of this script. It is recomended to leave Mixxx in fullscreen on the primary display.
#
# It is recommended to clear the AutoDJ queue after starting the script. Add at least two songs before starting
# the AutoDJ function in Mixxx to avoid playing the first song twice. The first song always gets requeued but
# it only plays once (unless AutoDJ was started in Mixxx with only one queued song).
# Songs are added to the AutoDJ queue in Mixxx by placing them in the music library, rescanning the library
# and relying on Mixxx to add the automatically. Mixxx adds random songs from the library to the queue whenever
# a song finishes playing. An unfortunate side effect of this is that if multiple songs are added while one
# song is playing the newly added songs are shuffled before being appended to the end of the queue.
#
# Known issues:
# -very long song names that only differ in the last parts of their names can be mistaken for each other
#
#
# Version 1.0 uses VLC instead of Mixxx and is simpler, more reliable and more lightweight. However, VLC does not
# support crossfading between songs and doesn't have the AutoDJ functionality that Mixxx has.

# Set the directory where AutoDJ will download all songs. It must be the Mixxx library or preferably a folder in it.
# No trailing slash!
download_location='/home/cartogan/Music/autodj'
# Time in ms to wait after reloading Mixxx music library
mixxx_lib_reload_time=500
# Time to wait between two clicks to avoid them being detected as a doubleckick
click_delay_time=500

# Helper function for trimming whitespace
trim()
{
    local var="$*"
    # remove leading whitespace characters
    var="${var#"${var%%[![:space:]]*}"}"
    # remove trailing whitespace characters
    var="${var%"${var##*[![:space:]]}"}"
    printf '%s' "$var"
}

# Runs in a child process, periodically checks if the next-in-queue song has changed.
# If it has, renames the audio file so Mixxx won't automatically add the same song again.
# The file is renamed and not deleted to prevent another process from overwriting the data on disk
# while Mixxx is playing the deleted but still open file.
song_file_remover()
{
	local mixxx_pid=$1
	sleep 10

	# Wait for a song to start playing
	mixxx_titlebar=$(xprop -id "$(xdo id -p $mixxx_pid)" _NET_WM_NAME | grep Mixxx | tr -d '"')
	mixxx_titlebar=${mixxx_titlebar//'_NET_WM_NAME(UTF8_STRING) = '/''}
	mixxx_wid=$(xdo id -a "$mixxx_titlebar")
	current_song_file=${mixxx_titlebar//' | Mixxx'/'.m4a'}
	# If no song is currently playing then the window title is just 'Mixxx'. Otherwise it contains the song name.
	while [[ $current_song_file == 'Mixxx' ]]
	do
		sleep 1
		mixxx_titlebar=$(xprop -id "$(xdo id -p $mixxx_pid)" _NET_WM_NAME | grep Mixxx | tr -d '"')
		mixxx_titlebar=${mixxx_titlebar//'_NET_WM_NAME(UTF8_STRING) = '/''}
		current_song_file=${mixxx_titlebar//' | Mixxx'/'.m4a'}
	done
	# Rename the currently playing file to keep the data from being overwritten but prevent Mixxx from
	# adding it back to the queue
	if [ -f "$download_location/$current_song_file" ]
	then
		rm "$download_location/.KUR" >/dev/null 2>&1
		mv "$download_location/$current_song_file" "$download_location/.KUR"
	fi
	alt_name=true
	prev_queued=''

	# Every time the queued song changes rename it
	while [ true ]
	do
		# Take a screenshot of the Mixxx window
		import -quiet -window "$mixxx_wid" /var/tmp/autodj/queue.png
		# Crop out the name of the next song
		# Below are the window size dependent coordinates. Make sure you adjust them to match your setup!
		convert /var/tmp/autodj/queue.png -crop 375x20+629+629 /var/tmp/autodj/queue_cropped.png
		convert /var/tmp/autodj/queue_cropped.png -channel RGB -negate /var/tmp/autodj/queue_cropped_inverted.png
		convert /var/tmp/autodj/queue_cropped_inverted.png +repage -crop 144x20+0+0 /var/tmp/autodj/artist.png
		convert /var/tmp/autodj/queue_cropped_inverted.png +repage -crop 231x20+145+0 /var/tmp/autodj/title.png
		# Read it using OCR
		artist=$(tesseract /var/tmp/autodj/artist.png - 2>/dev/null)
		artist=$(trim "$artist")
		title=$(tesseract /var/tmp/autodj/title.png - 2>/dev/null)
		title=$(trim "$title")
		artist=${artist//'...'/''}
		title=${title//'...'/''}
		queued=$(ls -1 $download_location | grep "$artist" | grep "$title")
		echo $queued

		if [[ $queued != $prev_queued ]]
		then
			# Wait for the transition between songs to finish
			sleep 12
			# Alternate between two bogus placeholder filenames
			if [ "$alt_name" = true ]
			then
					if [ -f "$download_location/$queued" ]
					then
						rm "$download_location/.KURCHE" >/dev/null 2>&1
						mv "$download_location/$queued" "$download_location/.KURCHE"
					fi
					alt_name=false
			else
					if [ -f "$download_location/$queued" ]
					then
						rm "$download_location/.KUR" >/dev/null 2>&1
						mv "$download_location/$queued" "$download_location/.KUR"
					fi
					alt_name=true
			fi
		fi

		prev_queued=$queued
		sleep 5
	done
}


# No, neither xdo nor xdotool works reliably for getting the PID of the parent terminal emulator
autodj_pid=$(ps -o ppid= -p $(ps -o ppid= -p $$) | awk '{$1=$1;print}')

rm "$download_location"/* >/dev/null 2>&1
mkdir -p /var/tmp/autodj

mixxx >/dev/null 2>&1 &
mixxx_pid=$!
sleep 3

# Failed attempt
#song_file_remover $mixxx_pid &

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
	sed '1,/Изпробване/d' /var/tmp/autodj/yt_results.html > /var/tmp/autodj/yt_results.txt
	# Obtain the URL of the first result
	url="https://www.youtube.com$(cat /var/tmp/autodj/yt_results.txt | grep watch | head -n 1)"
	echo $url

	if [ "$url" = 'https:://www.youtube.com' ]
	then
		continue
	fi

	# Download only the audio of this video
	yt-dlp -f "m4a" -o "$download_location/tmp/%(title).$(echo $max_filename_lenght)s.%(ext)s" --no-playlist $url

	# The new song will be the latest file in the directory
	filename="$(ls -t $download_location/tmp | head -n1)"
	if [ ! -f "$download_location/tmp/$filename" ]
	then
		continue
	fi
	existing_copies=$(ls $download_location | grep "${filename//.m4a/''}" | wc -l)

	# Move the file to another directory because youtube-dl sets the timestamps to weird values and
	# it cannot be determined which file is the latest
	if [ $existing_copies -gt 0 ]
	then
		mv "$download_location/tmp/$filename" "$download_location/${filename//.m4a/''}-${existing_copies}.m4a"
	else
		mv "$download_location/tmp/$filename" "$download_location/$filename"
	fi

	# Add the song to the current playlist
	xdo activate -p $mixxx_pid
	# The coordinates in the next command need to be adjusted according to the location of the 'Tracks',
	# 'AutoDJ' and 'Date Added' buttons in your Mixxx GUI
	# First it refreshes the library, then it clicks the 'Tracks' button, sorts the songs by date added,
	# selects the latest one, adds it to the AutoDJ queue and clicks the 'AutoDJ' button to show the queue.
	# Due to a bug in Mixxx sometimes the sorting gets messed up. That's why the songs must be resorted every time.
	xte 'keydown Alt_L' 'key l' 'keyup Alt_L' 'key Return' "usleep ${mixxx_lib_reload_time}000" 'mousemove 70 655' 'mouseclick 1' 'mousemove 1500 615' 'mouseclick 1' "usleep ${click_delay_time}000" 'mouseclick 1' 'key Down' 'key Menu' 'key Down' 'key Return' 'mousemove 70 680' 'mouseclick 1'
	xdo activate -p $autodj_pid
done
