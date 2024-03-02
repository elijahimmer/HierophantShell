#include <errno.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/wait.h>


const char *HELP_MESSAGE = "\
\
HNAT HSH help message\n\
\n\
usage: %s\n\
\
    --help\n\
        display this message\n\
    --cmd <command> [arg1] [arg2] ...\n\
        run a shell command\n\
";


void run_command(int argc, char **argv) {
    pid_t pid;
    int wstatus;

    if (signal(SIGCHLD, SIG_IGN) == SIG_ERR) {
        perror("signal");
        exit(EXIT_FAILURE);
    }

    switch ((pid = fork())) {
        case -1:
            perror("fork");
            exit(EXIT_FAILURE);
        case 0:
            puts(argv[0]);
            if (execvp(argv[0], argv) == -1) {
                perror(argv[0]);
                exit(EXIT_FAILURE);
            }

            exit(EXIT_SUCCESS);
        default:
            waitpid(pid, &wstatus, 0);
            puts("Hello from main");
    }
}

int main(int argc, char *argv[]) {
    char *name;
    if (argc < 1) {
        name = "hsh";
    } else {
        name = argv[0];
    }

    if (argc < 2) {
        printf(HELP_MESSAGE, name);
        exit(EXIT_FAILURE);
    }

    if (strcmp("--cmd", argv[1]) == 0) {
        if (argc < 3) {
            printf("Supply a command to run it!");
            exit(EXIT_FAILURE);
        }

        char *args[argc - 2];

        for (int i = 2; i < argc; i++) {
            args[i - 2] = argv[i];
        }

        run_command(argc - 2, args);

        exit(EXIT_SUCCESS);
    }

    exit(EXIT_SUCCESS);
}

