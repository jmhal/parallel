#include <stdio.h>
#include <stdlib.h>
#include "mpi.h"

int main(int argc, char *argv[]) {
    int numprocs, rank, tag = 100, msg_size = 64;
    char *buf;
    MPI_Status status;

    MPI_Init(&argc, &argv);
    MPI_Comm_size(MPI_COMM_WORLD, &numprocs);

    if (numprocs != 2)     {
        printf("São necessários 2 processos!\n");
        MPI_Finalize();
        return (0);
    }
    
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    printf("Processo MPI %d incializado ...\n", rank);
    fflush(stdout);
    while (msg_size < 10000000) {
        msg_size = msg_size * 2;
        buf = (char *)malloc(msg_size * sizeof(char));
        if (rank == 0) {
            MPI_Request send_request;
            MPI_Request recv_request;

            MPI_Isend(buf, msg_size, MPI_BYTE, rank + 1, tag, MPI_COMM_WORLD, &send_request);
            printf("Mensagem de tamanho %d para processo %d\n", msg_size, rank + 1);
            fflush(stdout);
            MPI_Irecv(buf, msg_size, MPI_BYTE, rank + 1, tag, MPI_COMM_WORLD, &recv_request);
            
            // do some work. 

            MPI_Wait(&send_request, &status);
            MPI_Wait(&recv_request, &status);
        }
        if (rank == 1) {
            MPI_Request send_request;
            MPI_Request recv_request;

            MPI_Isend(buf, msg_size, MPI_BYTE, rank - 1, tag, MPI_COMM_WORLD, &send_request);
            printf("Mensagem  de tamanho %d para processo %d\n", msg_size, rank - 1);
            fflush(stdout);
            MPI_Irecv(buf, msg_size, MPI_BYTE, rank - 1, tag, MPI_COMM_WORLD, &recv_request);

            // do some work.

            MPI_Wait(&send_request, &status);
            MPI_Wait(&recv_request, &status);
        }
        free(buf);
    }
    MPI_Finalize();
}