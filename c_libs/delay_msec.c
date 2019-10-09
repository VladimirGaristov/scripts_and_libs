#include <time.h>

void delay(int msec)
{
	clock_t start, current = 0;
	start = clock();
	while ((((float) (current - start)) / CLOCKS_PER_SEC) * 1000.0 < msec)
	{
		current = clock();
	}
}
