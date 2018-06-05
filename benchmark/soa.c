#include <stdlib.h>
#include <string.h>

#define NUM_PARTICLES 134217728

#define FORCE_X 1.0
#define FORCE_Y 2.5
#define FORCE_Z 0.3

#define VALUE_X 6.2
#define VALUE_Y 2.7
#define VALUE_Z 1.1

typedef struct {
  double *x;
  double *y;
  double *z;
  int *cold_fields;
} particles;

particles data;

int main(int argc, char **argv) {
  char *mode = argv[1];

  data.x = (double *) malloc(sizeof(double) * NUM_PARTICLES);
  data.y = (double *) malloc(sizeof(double) * NUM_PARTICLES);
  data.z = (double *) malloc(sizeof(double) * NUM_PARTICLES);
  data.cold_fields = (int *) malloc(sizeof(int) * 10 * NUM_);

  // Push all particles in one direction.
  if (strcmp(mode, "force") == 0) {
    for (long i = 0; i < NUM_PARTICLES; i++) {
      data.x[i] += FORCE_X;
    }
    for (long i = 0; i < NUM_PARTICLES; i++) {
      data.y[i] += FORCE_Y;
    }
    for (long i = 0; i < NUM_PARTICLES; i++) {
      data.z[i] += FORCE_Z;
    }
  // Update each individual particle.
  } else if (strcmp(mode, "update") == 0) {
    for (int i = 0; i < NUM_PARTICLES; i++) {
      data.x[i] = VALUE_X;
      data.y[i] = VALUE_Y;
      data.z[i] = VALUE_Z;
    }
  }

  free(data.x);
  free(data.y);
  free(data.z);

  return 0;
}
