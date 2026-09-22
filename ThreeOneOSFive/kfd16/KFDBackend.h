#ifndef KFDBackend_h
#define KFDBackend_h

#include <stdint.h>
#include <stdbool.h>

bool kfd16_candidate_for_current_device(void);
int kfd16_open_for_current_device(void);
void kfd16_close(void);
bool kfd16_is_active(void);
bool kfd16_read(uint64_t address, void *buffer, uint64_t size);
bool kfd16_write(uint64_t address, const void *buffer, uint64_t size);

#endif
