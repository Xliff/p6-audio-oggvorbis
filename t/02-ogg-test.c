#include <stdio.h>
#include <stdlib.h>
#include <ogg/ogg.h>

void main(int argv, char **argc) {

	ogg_sync_state s;
	ogg_page p;
	int ret;
	char *b;
	FILE *f;

	b = (char *)malloc(4096);

	ret = ogg_sync_init(&s);

	ret = ogg_sync_pageout(&s, &p);
	b = ogg_sync_buffer(&s, 4096);

	f = fopen("resources/SoundMeni.ogg", "r");
	fread(b, 4096, 1, f);
	ret = ogg_sync_wrote(&s, 4096);

	printf("R1: %d\n", ret);

	b = ogg_sync_buffer(&s, 4096);
	printf("R2: %d\n", ret);

	printf("ogg_stream_state: %d\n", sizeof(ogg_stream_state));
	
	fclose(f);
}
