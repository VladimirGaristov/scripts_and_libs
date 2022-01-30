<!DOCTYPE html>
<html>
	<body>
		<?php
			if (isset($_POST['song_name']))
			{
				$fp = fopen("songlist.txt", "a") or die("Unable to open file");
				$song_name = $_POST['song_name']."\n";
				fwrite($fp, $song_name);
				fclose($fp);
			}
		?>

		<form action="autodj.php" method="post">
		Song title: 
		<input type="text" name="song_name">
		<br>
		<input type="submit" value="Request">
		</form>
	</body>
</html>