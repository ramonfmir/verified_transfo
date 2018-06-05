#include <stdlib.h>
#include <time.h>
#include <string.h>

#define NUM_PARTICLES 134217728 // 2^27
#define BLOCK_SIZE 128 // 2^7
#define NB_BLOCKS 1048576 // 2^20

#define K1 1.33
#define K2 3.07

#define DENSITY 0.2

typedef struct {
  // Position
  float x, y, z;
  // Velocity
  float vx, vy, vz;
  // Charge
  float c;
  // Mass, volume (unused)
  float m, v;
} particle;

particle *data;
int *counts;

int main(int argc, char **argv) {
  char *mode = argv[1];

  data = (particle *) calloc(NUM_PARTICLES, sizeof(particle));
  counts = (int *) calloc(NB_BLOCKS, sizeof(int));

  // Do something to all particles.
  if (strcmp(mode, "apply_action") == 0) {
    for (int i = 0; i < NUM_PARTICLES; i++) {
      data[i].x += data[i].vx;
      data[i].y += data[i].vy + K1 * data[i].c;
      data[i].z += data[i].vz * K2;
    }
  // Populate the scene with particles in random positions.
  } else if (strcmp(mode, "populate") == 0) {
    srand(time(NULL));
    for (int i = 0; i < NUM_PARTICLES * DENSITY; ) {
      int block_index = rand() % NB_BLOCKS;
      int *count = &(counts[block_index]);
      if (*count < BLOCK_SIZE) {
        int index = block_index + *count;
        data[index].x  = (float) rand();
        data[index].y  = (float) rand();
        data[index].z  = (float) rand();
        data[index].vx = (float) rand();
        data[index].vy = (float) rand();
        data[index].vz = (float) rand();
        data[index].c  = (float) rand();
        data[index].m  = (float) rand();
        data[index].v  = (float) rand();

        *count = *count + 1;
        i++;
      }
    }
  }

  free(data);
  free(counts);

  return 0;
}
