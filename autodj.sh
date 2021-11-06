#!/bin/bash
#Make sure xml-twig-tools is installed	(no longer needed!)

vlc --one-instance >/dev/null 2>&1 &
sleep 1

#No trailing slash!
download_location='/home/cartogan/Videos/autodj'

#Unicode symbols in video titles are escaped as bytes which are represented with \x notation
#For example the cyrilic letter "Щ" (sht) becomes "\xd0\xa9" - 8 bytes in total
#The maximum filename lenght on most filesystems, including ext4, is 255 bytes
#The filename during download ends in .webm.part (10 bytes) and \0 (I think?)
#This suggests that the maximum title lenght if only cyrillic letters are used is (255 - 11) / 8 = 30
#In practice the script works fine with titles that include 50+ cyrilic letters but breaks somewhere around 60, needs more testing
#So basically, I got annoyed by this ungodly crap and eyeballed the lenght limit
max_filename_lenght='60'

song='-'

rm /home/cartogan/Videos/autodj/tmp/* >/dev/null 2>&1
printf "Na bai Vlado scripta!\nX za izhod\n"

#The authentication is needed for age-restricted videos by throws errors
#printf "\nVavedi potrebitelsko ime v YouTube: "
#read user
#printf "\nVavedi parola za YouTube: "
#read -s pass

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
	sed '1,/Изпробване/d' tmp.txt > out.txt
	#Obtain the URL of the first result
	#url="https://www.youtube.com$(xmllint --html --xpath "string(//a[1 and @aria-hidden='true']/@href)" tmp.txt)"
	url="https://www.youtube.com$(cat out.txt | grep watch | head -n 1)"
	echo $url

	if [ "$url" = 'https:://www.youtube.com' ]
	then
		continue
	fi

	#Download only the audio of this video
	#youtube-dl -f 250 -o "$download_location/tmp/%(title).%(ext)s" -no-playlist $url
	#youtube-dl -u $user --password $pass -f "171/bestaudio" -o "$download_location/tmp/%(title).255s.%(ext)s" --no-playlist $url
	youtube-dl -f "171/bestaudio" -o "$download_location/tmp/%(title).$(echo $max_filename_lenght)s.%(ext)s" --no-playlist $url

	#The new song will be the latest file in the directory
	filename="$(ls -t $download_location/tmp | head -n1)"
	if [ ! -f "$download_location/tmp/$filename" ]
	then
		continue
	fi

	#Move the file to another directory because youtube-dl sets the timestamps to weird values and it cannot be determined which file is the latest
	mv "$download_location/tmp/$filename" "$download_location/$filename"

	#Add the song to the current playlist
	vlc --one-instance --playlist-enqueue "$download_location/$filename"
done
