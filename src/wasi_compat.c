#include <unistd.h>
#include <errno.h>

/*
** WASI Preview 1 does not provide gethostname().
** Provide a POSIX-compliant stub returning -1 with ENOSYS.
*/
int gethostname(char *name, size_t len) {
    if (len > 0 && name != NULL) {
        name[0] = '\0';
    }
    errno = ENOSYS;
    return -1;
}
