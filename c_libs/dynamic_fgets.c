char *read_string(struct sp_port *stream)
{
	char *buffer = NULL;
	int bytes_read = 0;
	int blocks = 1;
	do
	{
		//allocate memory for an additional chunk of the string
		buffer = realloc(buffer, BUFFER_INCR * sizeof(*buffer) * blocks);
		if (buffer == NULL)
		{
			return NULL;
		}
		//read a chunk of the string
		bytes_read = sp_blocking_read(ser_port, buffer + BUFFER_INCR * (blocks - 1),
			BUFFER_INCR, TIMEOUT);
		blocks++;
	}
	while (bytes_read == BUFFER_INCR);
	return buffer;
}
