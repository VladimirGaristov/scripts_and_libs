<!DOCTYPE html>
<html>
	<body>
		<?php
			function strip_first_line($text)
			{        
				return substr($text, strpos($text, "\n") + 1);
			}

			if (isset($_POST['song_name']))
			{
				$song_name = $_POST['song_name']."\n";
				if (0 == strcmp(trim($song_name), "72DkILZfdCutpUxMc50846ChapOhAaJrXaNGanaqdQb3hxhLDZHq48JgBRre3eSqrsu2fEY09oMgPmnnjN1l5deqzVrjrLdXwyGSXL7FX07sy8jXEunqhzruGaZNBtev"))
				{
					$songlist = file_get_contents('songlist.txt');
					$songlist = strip_first_line($songlist);
					file_put_contents('songlist.txt', $songlist);
				}
				else
				{
					$fp = fopen("songlist.txt", "a") or die("Unable to open file");
					fwrite($fp, $song_name);
					fclose($fp);
				}
			}
		?>

		<form action="autodj.php" method="post">
		Song title: 
		<input type="text" name="song_name">
		<br>
		<input type="submit" value="Request">
		</form>

		<button onclick="window.location.href='https://garistov.idiotempire.com';">
			Back
		</button>
	</body>
</html>