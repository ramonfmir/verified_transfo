#include <stdlib.h>
#include <string.h>

#define NUM_PARTICLES 134217728
#define BUCKET_SIZE 128
#define NUM_BUCKETS (NUM_PARTICLES / BUCKET_SIZE)

#define FORCE_X 1.0
#define FORCE_Y 2.5
#define FORCE_Z 0.3

#define VALUE_X 6.2
#define VALUE_Y 2.7
#define VALUE_Z 1.1

typedef struct {
  double x, y, z;
  int cold_fields[10];
} particle;

typedef struct {
  int bid;
  particle items[BUCKET_SIZE];
} bucket;

bucket *data;

int main(int argc, char **argv) {
  char *mode = argv[1];

  data = (bucket *) malloc(sizeof(bucket) * NUM_BUCKETS);

  // Push all particles in one direction.
  if (strcmp(mode, "force") == 0) {
    for (long i = 0; i < NUM_BUCKETS; i++) {
      for (long j = 0; j < BUCKET_SIZE; j++) {
        data[i].items[j].x += FORCE_X;
        data[i].items[j].y += FORCE_Y;
        data[i].items[j].z += FORCE_Z;
      }
    }
  // Update each individual particle.
  } else if (strcmp(mode, "update") == 0) {
    /*for (int i = 0; i < NUM_PARTICLES; i++) {
      data[i].x = VALUE_X;
      data[i].y = VALUE_Y;
      data[i].z = VALUE_Z;
    }*/
  }

  free(data);

  return 0;
}
