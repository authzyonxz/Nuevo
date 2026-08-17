#ifndef _SYS_FILEPORT_H_
#define _SYS_FILEPORT_H_

#include <sys/cdefs.h>
#include <sys/_types.h>

__BEGIN_DECLS

typedef __darwin_mach_port_t fileport_t;
#define FILEPORT_NULL ((fileport_t)0)

int fileport_makeport(int fd, fileport_t *port);
int fileport_makefd(fileport_t port);

__END_DECLS

#endif
