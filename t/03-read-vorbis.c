#include <stdlib.h>
#include <stdio.h>

int floatArrayTest(float **pa) {
	*pa = malloc(sizeof(float *) * 500);
	float *pac = *pa;
	if (pac == NULL) {
		return -1;
	}

	int i;
	for (i = 0; i < 500; i++) {
		pac[i] = i + 0.5f;
	}

	return 0;
}

int pointerArrayTest(float ***pa) {
	//printf("pa is %x\n", pa);

	*pa = (float **)malloc(sizeof(float **) * 5);
	float **pac = *pa;
	if (pac == NULL) {
		return -1;
	}

	int c;
	int v = 0;
	for (c = 0; c < 5; c++) {
		pac[c] = (float *)malloc(sizeof(float) * 500);
		if (pac[c] == NULL) {
			return -1;
		}

		int s;
		for (s = 0; s < 500; s++) {
			pac[c][s] = v++;
		}
	}

	return 0;
}

int main (int argc, char **argv) {
	float **arr;

	printf("arr is %x\n", &arr);

	if (pointerArrayTest(&arr) == -1) {
		printf("Allocation error!");
		exit(1);
	}

	printf("arr is %x\n", &arr);

	int c;
	int s;
	//for (c = 0; c < 5; c++) {
		//printf("Address of arr[%d] = %lx\n", c, arr[c]);

		// cw: Data structure is corrupted by this point.
		for (s = 300; s < 500; s++) {
			printf("S1: %.0f\n", arr[4][s]);
		}
		//break;
	//}

	// cw: Yarr! We leak like a sieve and DON'T CARE!
	float *arr2;
	if (floatArrayTest(&arr2) == -1) {
		printf("Allocation error!");
		exit(1);
	}		
	for (s = 0; s < 500; s++) {
		printf("S2: %.1f\n", arr2[s]);
	}
}