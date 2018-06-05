#include <stdlib.h>
#include <string.h>

#define NUM_PARTICLES 134217728
#define BLOCK_SIZE 16
#define NB_BLOCKS (NUM_PARTICLES / BLOCK_SIZE)

#define FORCE_X 1.0
#define FORCE_Y 2.5
#define FORCE_Z 0.3

#define VALUE_X 6.2
#define VALUE_Y 2.7
#define VALUE_Z 1.1

typedef struct {
  double x[BLOCK_SIZE];
  double y[BLOCK_SIZE];
  double z[BLOCK_SIZE];
} particle_block;

particle_block *data;

int main(int argc, char **argv) {
  char *mode = argv[1];

  data = (particle_block *) malloc(sizeof(particle_block) * NB_BLOCKS);

  // Push all particles in one direction.
  if (strcmp(mode, "force") == 0) {
    for (int i = 0; i < NUM_PARTICLES / BLOCK_SIZE; i++) {
      double *x = data[i].x;
      double *y = data[i].y;
      double *z = data[i].z;

      for (int j = 0; j < BLOCK_SIZE; j++) {
        x[j] += FORCE_X;
      }
      for (int j = 0; j < BLOCK_SIZE; j++) {
        y[j] = y[j] + FORCE_Y;
      }
      for (int j = 0; j < BLOCK_SIZE; j++) {
        z[j] = z[j] + FORCE_Z;
      }
    }
  // Update each individual particle.
  } else if (strcmp(mode, "update") == 0) {
    for (int i = 0; i < NUM_PARTICLES / BLOCK_SIZE; i++) {
      double *x = data[i].x;
      double *y = data[i].y;
      double *z = data[i].z;

      for (int j = 0; j < BLOCK_SIZE; j++) {
        x[j] = VALUE_X;
        y[j] = VALUE_Y;
        z[j] = VALUE_Z;
      }
    }
  }

  free(data);

  return 0;
}
