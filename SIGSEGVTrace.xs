#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <signal.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <sys/types.h>
#include <sys/ioctl.h>

/* must never be less than 3 */
#define BUF_SIZE 4096

static char exec_path[200];
static char command_path[200];
static char core_path_base[200];
int skreech_to_a_halt = 0;

void read_write(int rd, int wd);

#define SIGSEGV_DEBUG 0
#if SIGSEGV_DEBUG
void Debug( const char * format, ...)
{
    va_list args;

    va_start(args, format);
    /* fprintf(stderr, "debug: "); */
    vfprintf(stderr, format, args);
    va_end(args);
}
#else
void Debug()
{
}
#endif

void
sig_handler (int signal)
{
    skreech_to_a_halt++;
}

static void SIGSEGV_handler(int signal)
{
    int ifd[2], ofd[2];
    FILE *core;
    char buf[BUF_SIZE+1];
    pid_t pid;
    char pid_opt[20];
    char command[200];
    char core_file[200];
    const char *args[] = {
        "gdb", 
        "--batch",
        "--quiet",
        NULL,
        NULL,
        NULL,
        NULL
    };

    /* gdb reads the command from this file */
    sprintf(command, "--command=%s", command_path);
    args[3] = command;
    args[4] = exec_path;
    /* sprintf(pid_opt, "--pid=%d", (int)getpid()); */
    sprintf(pid_opt, "%d", (int)getpid());
    args[5] = pid_opt;

    /* the core will be written into this file */
    sprintf(core_file, "%s%d", core_path_base, getpid());
    
    fprintf(stderr, "SIGSEGV (Segmentation fault) in %d\n", getpid());
        
    Debug("openning core trace file: %s\n", core_file);
    if ((core = fopen(core_file, "w+")) == NULL) {
        fprintf(stderr, "failed to open %s for writing ", core_file);
        perror("");
        exit(0);
    }
            
    if (pipe(ifd) == -1) {
        Perl_croak(aTHX_ "can't open pipe: %s", strerror(errno));
    }
    if (pipe(ofd) == -1) {
        Perl_croak(aTHX_ "can't open pipe: %s", strerror(errno));
    }

    if((pid = fork()) == -1) {
        close (ifd[0]);
        close (ifd[1]);
        close (ofd[0]);
        close (ofd[1]);
        Perl_croak(aTHX_ "couldn't fork '%s'", strerror(errno));
    }

    if (!pid) { /* child */
        close(ofd[0]);
        fclose(stdout);
        dup(ofd[1]);

        close(ifd[1]);
        fclose(stdin);
        dup(ifd[0]);

        Debug("%s %s %s %s %s %s\n", args[0], args[1], args[2],
              args[3], args[4], args[5]);
        execvp(args[0], (char **)args);
        Perl_croak(aTHX_ "couldn't run '%s': %s", args[0], strerror(errno));
    }
    else { /* parent */
        FILE *file;
        int size;
        fd_set readset;

        fclose(stdin);
        close(ofd[1]);
        close(ifd[0]);

        /* fprintf(stderr, "parent: writing to gdb\n"); */
        /* write(ifd[1], command, sizeof(command)); */
        Debug("going to read from gdb\n");

        fprintf(stderr, "writing to the core file %s\n", core_file);
        fprintf(core, "The trace:\n");
        fflush(core);

        Debug("reading results\n");
        read_write(ofd[0], fileno(core));
    
        Debug("cleanup, deleting %s\n", buf);
        Debug("exiting\n");
    
        close(ifd[1]);
        close(ofd[0]);
        fclose(core);
        
        waitpid(pid, NULL, 0);  
        Debug("parent: gdb has returned\n");
        exit(0); 
    }
    
}


/* input: - a file descriptor to read from
 *        - a file descriptor to write to the read data
 */
void
read_write(int rd, int wd)
{
    fd_set rfds;
    struct timeval tv;
    ssize_t readlen, writelen;
    char buf[BUF_SIZE];
    int fd_flags;

    if ((fd_flags = fcntl(rd, F_GETFL, 0)) == -1)
        perror("Could not get flags for fd");
    if (fcntl(rd, F_SETFL, fd_flags | O_NONBLOCK) == -1)
        perror("Could not set flags for fd");

    signal(SIGINT, sig_handler);

    /* while we're connected... */
    while (!skreech_to_a_halt) {
        FD_ZERO(&rfds);
        FD_SET(rd, &rfds);

        /* for some reason, if I make usec == 0 (poll), performance sucks */
        tv.tv_sec = 0;
        tv.tv_usec = 1;

        if (select(rd + 1, &rfds, NULL, NULL, &tv)) {
            /* can read */
            Debug("can read...\n");
            if (FD_ISSET(rd, &rfds)) {
                Debug("reading\n");
                readlen = read(rd, buf, BUF_SIZE);
                if (readlen == -1) {
                    if (errno != EAGAIN) {
                        perror("read");
                    }
                    continue;
                }
                if (readlen == 0) {
                    /* all done */
                    skreech_to_a_halt = 1;
                    /* fflush(NULL); eh? */
                    continue;
                }
                /* Debug(buf); */
                writelen = write(wd, buf, readlen);
                if (writelen != readlen) {
                    perror("write");
                    break;
                }
            }
        }

    }

    fflush(NULL);
    return;

}

static void
crash_now_for_real(char *suicide_message)
{
    int *p = NULL;
    printf("%d", *p); /* cause a segfault */
}


static void
crash_now(char *suicide_message, int attempt_num)
{
    crash_now_for_real(suicide_message);
}

MODULE=Debug::SIGSEGVFault PACKAGE=Debug::SIGSEGVFault PREFIX=sig_segv_fault_

void
sig_segv_fault_segv()

    CODE:
    crash_now("Cannot stand this life anymore", 42);

MODULE=Debug::SIGSEGVTrace PACKAGE=Debug::SIGSEGVTrace PREFIX=sig_segv_trace_

void
sig_segv_trace_set_segv_action(exec_path_in, command_path_in, core_path_base_in)
    char *exec_path_in
    char *command_path_in
    char *core_path_base_in
    
    PREINIT:
    struct sigaction sa;

    CODE:
    strcpy(exec_path, exec_path_in);
    strcpy(command_path, command_path_in);
    strcpy(core_path_base, core_path_base_in);

    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_RESETHAND; /* restore to the default on call */
    sa.sa_handler = SIGSEGV_handler;

    if (sigaction(SIGSEGV, &sa, NULL) < 0) {
        Perl_croak(aTHX_ "cannot set SIGSEGV action");
    }


