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
  double x, y, z;
} particle;

particle *data;

int main(int argc, char **argv) {
  char *mode = argv[1];

  data = (particle *) malloc(sizeof(particle) * NUM_PARTICLES);

  // Push all particles in one direction.
  if (strcmp(mode, "force") == 0) {
    for (int i = 0; i < NUM_PARTICLES; i++) {
      data[i].x = data[i].x + FORCE_X;
      data[i].y = data[i].y + FORCE_Y;
      data[i].z = data[i].z + FORCE_Z;
    }
  // Update each individual particle.
  } else if (strcmp(mode, "update") == 0) {
    for (int i = 0; i < NUM_PARTICLES; i++) {
      data[i].x = VALUE_X;
      data[i].y = VALUE_Y;
      data[i].z = VALUE_Z;
    }
  }

  free(data);

  return 0;
}
