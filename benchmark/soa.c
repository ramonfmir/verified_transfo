#include <stdlib.h>
#include <time.h>
#include <string.h>

#define NUM_PARTICLES (1 << 27) // 2^27
#define BLOCK_SIZE (1 << 12) // 2^12
#define NB_BLOCKS (1 << 15) //2^15

#define K1 1.33
#define K2 3.07

#define DENSITY 0.2

typedef struct {
  // Position
  float *x;
  float *y;
  float *z;
  // Velocity
  float *vx;
  float *vy;
  float *vz;
  // Charge
  float *c;
  // Mass, volume (unused)
  float *m;
  float *v;
  // Counts, used for populating
  int *counts;
} particles;

particles data;

int main(int argc, char **argv) {
  char *mode = argv[1];

  data.x  = (float *) calloc(NUM_PARTICLES, sizeof(float));
  data.y  = (float *) calloc(NUM_PARTICLES, sizeof(float));
  data.z  = (float *) calloc(NUM_PARTICLES, sizeof(float));
  data.vx = (float *) calloc(NUM_PARTICLES, sizeof(float));
  data.vy = (float *) calloc(NUM_PARTICLES, sizeof(float));
  data.vz = (float *) calloc(NUM_PARTICLES, sizeof(float));
  data.c  = (float *) calloc(NUM_PARTICLES, sizeof(float));
  data.m  = (float *) calloc(NUM_PARTICLES, sizeof(float));
  data.v  = (float *) calloc(NUM_PARTICLES, sizeof(float));

  data.counts = (int *) calloc(NB_BLOCKS, sizeof(int));

  // Do something to all particles.
  if (strcmp(mode, "apply_action") == 0) {
    for (long i = 0; i < NUM_PARTICLES; i++) {
      data.x[i] += data.vx[i];
    }
    for (long i = 0; i < NUM_PARTICLES; i++) {
      data.y[i] += data.vy[i] + K1 * data.c[i];
    }
    for (long i = 0; i < NUM_PARTICLES; i++) {
      data.z[i] += data.vz[i] * K2;
    }
  // Populate the scene with particles in random positions.
  } else if (strcmp(mode, "populate") == 0) {
    srand(time(NULL));
    for (int i = 0; i < NUM_PARTICLES * DENSITY; ) {
      int block_index = rand() % NB_BLOCKS;
      int *count = &(data.counts[block_index]);

      if (*count < BLOCK_SIZE) {
        int index = block_index + *count;
        data.x[index]  = (float) rand();
        data.y[index]  = (float) rand();
        data.z[index]  = (float) rand();
        data.vx[index] = (float) rand();
        data.vy[index] = (float) rand();
        data.vz[index] = (float) rand();
        data.c[index]  = (float) rand();
        data.m[index]  = (float) rand();
        data.v[index]  = (float) rand();

        (*count)++;
        i++;
      }
    }
  }

  free(data.x);
  free(data.y);
  free(data.z);
  free(data.vx);
  free(data.vy);
  free(data.vz);
  free(data.c);
  free(data.counts);

  return 0;
}
