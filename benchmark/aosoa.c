#include <stdlib.h>
#include <string.h>

#define NUM_PARTICLES 134217728
#define BLOCK_SIZE 4096
#define NB_BLOCKS (NUM_PARTICLES / BLOCK_SIZE)

#define DENSITY 0.25

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

int main(int argc, char **argv) {
  char *mode = argv[1];

  data = (particle_block *) malloc(sizeof(particle_block) * NB_BLOCKS);

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

  }

  free(data);

  return 0;
}
