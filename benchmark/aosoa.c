#include <stdlib.h>
#include <time.h>
#include <string.h>

// Note that the blocks here are used differenty.
#define NUM_PARTICLES 134217728 // 2^27
#define BLOCK_SIZE 128 // 2^7
#define NB_BLOCKS 1048576 // 2^20

#define DENSITY 0.2

#define K1 1.33
#define K2 3.07

typedef struct {
  // Position
  float x[BLOCK_SIZE];
  float y[BLOCK_SIZE];
  float z[BLOCK_SIZE];
  // Velocity
  float vx[BLOCK_SIZE];
  float vy[BLOCK_SIZE];
  float vz[BLOCK_SIZE];
  // Charge
  float c[BLOCK_SIZE];
  // Mass, volume (unused)
  float m[BLOCK_SIZE];
  float v[BLOCK_SIZE];
} particle_block;

particle_block *data;
int *counts;

int main(int argc, char **argv) {
  char *mode = argv[1];

  data = (particle_block *) calloc(NB_BLOCKS, sizeof(particle_block));
  counts = (int *) calloc(NB_BLOCKS, sizeof(int));

  // Do something to all particles.
  if (strcmp(mode, "apply_action") == 0) {
    for (int i = 0; i < NB_BLOCKS; i++) {
      for (int j = 0; j < BLOCK_SIZE; j++) {
        data[i].x[j] += data[i].vx[j];
      }
      for (int j = 0; j < BLOCK_SIZE; j++) {
        data[i].y[j] += data[i].vy[j] + K1 * data[i].c[j];
      }
      for (int j = 0; j < BLOCK_SIZE; j++) {
        data[i].z[j] += data[i].vz[j] * K2;
      }
    }
  // Populate the scene with particles in random positions.
  } else if (strcmp(mode, "populate") == 0) {
    srand(time(NULL));
    for (int i = 0; i < NUM_PARTICLES * DENSITY; ) {
      int block_index = rand() % NB_BLOCKS;
      int *count = &(counts[block_index]);
      if (*count < BLOCK_SIZE) {
        data[block_index].x[*count]  = (float) rand();
        data[block_index].y[*count]  = (float) rand();
        data[block_index].z[*count]  = (float) rand();
        data[block_index].vx[*count] = (float) rand();
        data[block_index].vy[*count] = (float) rand();
        data[block_index].vz[*count] = (float) rand();
        data[block_index].c[*count]  = (float) rand();
        data[block_index].m[*count]  = (float) rand();
        data[block_index].v[*count]  = (float) rand();

        *count = *count + 1;
        i++;
      }
    }
  }

  free(data);
  free(counts);

  return 0;
}
