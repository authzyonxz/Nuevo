#ifndef _XPC_XPC_H_
#define _XPC_XPC_H_

#include <sys/cdefs.h>
#include <stdint.h>
#include <stdbool.h>

__BEGIN_DECLS

typedef void * xpc_object_t;
typedef void * xpc_type_t;

extern const struct _xpc_type_s _xpc_type_uint64;
#define XPC_TYPE_UINT64 (&_xpc_type_uint64)

xpc_object_t xpc_null_create(void);
xpc_type_t xpc_get_type(xpc_object_t object);
bool xpc_dictionary_apply(xpc_object_t xdict, bool (^applier)(const char *key, xpc_object_t value));
uint64_t xpc_uint64_get_value(xpc_object_t xuint);
void xpc_dictionary_set_uint64(xpc_object_t xdict, const char *key, uint64_t value);
xpc_object_t xpc_dictionary_create_empty(void);
void xpc_release(xpc_object_t object);

__END_DECLS

#endif
