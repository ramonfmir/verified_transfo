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
} particles;

particles data;

int main(int argc, char **argv) {
  char *mode = argv[1];

  data.x  = (float *) malloc(sizeof(float) * NUM_PARTICLES);
  data.y  = (float *) malloc(sizeof(float) * NUM_PARTICLES);
  data.z  = (float *) malloc(sizeof(float) * NUM_PARTICLES);
  data.vx = (float *) malloc(sizeof(float) * NUM_PARTICLES);
  data.vy = (float *) malloc(sizeof(float) * NUM_PARTICLES);
  data.vz = (float *) malloc(sizeof(float) * NUM_PARTICLES);
  data.c  = (float *) malloc(sizeof(float) * NUM_PARTICLES);

  // Push all particles in one direction.
  if (strcmp(mode, "force") == 0) {
    for (long i = 0; i < NUM_PARTICLES; i++) {
      data.x[i] += data.vx[i];
    }
    for (long i = 0; i < NUM_PARTICLES; i++) {
      data.y[i] += data.vy[i] + FORCE_Y * data.c[i];
    }
    for (long i = 0; i < NUM_PARTICLES; i++) {
      data.z[i] += data.vz[i] * FORCE_Z;
    }
  // Push individual particles.
  } else if (strcmp(mode, "update") == 0) {

  }

  free(data.x);
  free(data.y);
  free(data.z);
  free(data.vx);
  free(data.vy);
  free(data.vz);
  free(data.c);

  return 0;
}
