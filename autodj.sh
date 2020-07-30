#!/bin/bash
#Make sure xml-twig-tools is installed
vlc --one-instance >/dev/null 2>&1 &
sleep 1
song="-"
rm /home/cartogan/Videos/autodj/tmp/*
printf "\nVavedi potrebitelsko ime v YouTube: "
read user
printf "\nVavedi parola za YouTube: "
read -s pass
while [ true ]
do
	#Input song name
	printf "\nVavedi ime na pesen i natisni Enter: "
	read song
	#Input X to exit the script
	if [ "$song" = 'X' ]
	then
		exit 0
	fi
	if [ "$song" = '' ]
	then
		continue
	fi
	#Replace spaces with + in the song name
	song=${song// /+}
	#Download the youtube page with search results for videos with this name
	curl "https://www.youtube.com/results?search_query=$song" > tmp.txt
	sed -i -e 's/\"/\n/g' tmp.txt
	#Obtain the URL of the first result
	#url="https://www.youtube.com$(xmllint --html --xpath "string(//a[1 and @aria-hidden='true']/@href)" tmp.txt)"
	url="https://www.youtube.com$(grep 'watch' tmp.txt | head -n 19 | tail -n 1)"
	echo $url
	if [ "$url" = 'https:://www.youtube.com' ]
	then
		continue
	fi
	#Download only the audio of this video
	#youtube-dl -f 250 -o "/home/cartogan/Videos/autodj/tmp/%(title)s.%(ext)s" -no-playlist $url
	youtube-dl -u $user --password $pass -f "171/bestaudio" -o "/home/cartogan/Videos/autodj/tmp/%(title)s.%(ext)s" --no-playlist $url
	#The new song will be the latest file in the directory
	filename="$(ls -t /home/cartogan/Videos/autodj/tmp | head -n1)"
	if [ ! -f "/home/cartogan/Videos/autodj/tmp/$filename" ]
	then
		continue
	fi
	#Move the file to anither directory because youtube-dl sets the timestamps to weird values and it cannot be determined which file is the latest
	mv "/home/cartogan/Videos/autodj/tmp/$filename" "/home/cartogan/Videos/autodj/$filename"
	#Add the song to the current playlist
	vlc --one-instance --playlist-enqueue "/home/cartogan/Videos/autodj/$filename"
done
