#include "projeto.cuh"
#include <string.h>
#include <stdlib.h>
#include <cuda.h>

#include <string.h>
#include <cstdio>


unsigned long long int calculaNPrefixos(const int nivelPrefixo, const int nVertice, const int intervalo, const int rank) {
  unsigned long long int x = nVertice - 1;
  int i;

  x = intervalo;
   if(rank == 0)
    x--;

  for (i = 1; i < nivelPrefixo-1; ++i) {
    x *= nVertice - i-1;
  }
    return x;
}



unsigned long long int calculaNPrefixos(const int nivelPrefixo, const int nVertice) {
  unsigned long long int x = nVertice - 1;
  int i;
  for (i = 1; i < nivelPrefixo-1; ++i) {
    x *= nVertice - i-1;
  }
  return x;
}


// int fillFixedPaths(short* preFixo, int nivelPrefixo,int inicio,int fim) {

//   printf("\n");


//   char flag[20];
//   int vertice[20]; 
//   int cont = 0;
//   int i, nivel;
//   bool teste; 

//   for (i = 0; i < N; ++i) {
//     flag[i] = 0;
//     vertice[i] = -1;
//   }

//   vertice[0] = 0; 

//   flag[0] = 1;

//   nivel = 1;
//   while (nivel >= 1){

//     if (vertice[nivel] != -1) {
//       flag[vertice[nivel]] = 0;
//     }


//     if(nivel == 1 ){//assegurando que apenas o intervalo seja utilizado como raiz de nivel 1
//         for(int i = 1; i<N;++i){
//             if(i<inicio || i>fim)
//               flag[i] = 1;
//         }

//     }


//     do {

//         vertice[nivel]++;

//     } while (vertice[nivel] < N && flag[vertice[nivel]]); //enquanto for menor que N e nao estiver visitado
    

//     if(nivel == 1 ){//assegurando que apenas o intervalo seja utilizado como raiz de nivel 1
//         for(int i = 1; i<N;++i){
//             if(i<inicio || i>fim)
//               flag[i] = 0;
//         }

//     }



//     if (vertice[nivel] < N) { 
      
//       flag[vertice[nivel]] = 1;
//       nivel++;

//       if (nivel == nivelPrefixo) {
//         for (i = 0; i < nivelPrefixo; ++i) {
//           preFixo[cont * nivelPrefixo + i] = vertice[i];
//         }
//         cont++;
//         nivel--;
//       }
//     } else {
//       vertice[nivel] = -1;
//       nivel--;
//     }
//   }

//   return cont;
// }

// void checkCUDAError(const char *msg) {
//   cudaError_t err = cudaGetLastError();
//   if (cudaSuccess != err) {
//     fprintf(stderr, "Cuda error: %s: %s.\n", msg, cudaGetErrorString(err));
//     exit(EXIT_FAILURE);
//   }
// }


// static void HandleError( cudaError_t err,
//     const char *file,
//     int line ) {
//   if (err != cudaSuccess) {
//     printf( "%s in %s at line %d\n", cudaGetErrorString( err ),
//         file, line );
//     exit( EXIT_FAILURE );
//   }
// }


__global__ void dfs_cuda_UB_stream(int N,int stream_size, int *mat_d, 
  short *preFixos_d, int nivelPrefixo, int upper_bound, int *sols_d,
  int *melhorSol_d)
  {

  register int idx = blockIdx.x * blockDim.x + threadIdx.x;
  register int flag[16];
  register int vertice[16]; 

  register int N_l = N;

  register int i, nivel;
  register int custo;
  register int qtd_solucoes_thread = 0;
  register int UB_local = upper_bound;
  register int nivelGlobal = nivelPrefixo;
  int stream_size_l = stream_size;

  if (idx < stream_size_l) {

    for (i = 0; i < N_l; ++i) {
      vertice[i] = _VAZIO_;
      flag[i] = _NAO_VISITADO_;
    }

    vertice[0] = 0;
    flag[0] = _VISITADO_;
    custo= ZERO;

    //preenche o prefixo
    for (i = 1; i < nivelGlobal; ++i) {

      vertice[i] = preFixos_d[idx * nivelGlobal + i];

      flag[vertice[i]] = _VISITADO_;
      custo += mat_d(vertice[i-1],vertice[i]);
    }

    nivel=nivelGlobal;

    while (nivel >= nivelGlobal ) {
      if (vertice[nivel] != _VAZIO_) {
        flag[vertice[nivel]] = _NAO_VISITADO_;
        custo -= mat_d(vertice[anterior(nivel)],vertice[nivel]);
      }

      do {
        vertice[nivel]++;
      } while (vertice[nivel] < N_l && flag[vertice[nivel]]); 
      
      if (vertice[nivel] < N_l) {
        custo += mat_d(vertice[anterior(nivel)],vertice[nivel]);
        flag[vertice[nivel]] = _VISITADO_;
        nivel++;

        if (nivel == N_l) {
          ++qtd_solucoes_thread;
          if (custo + mat_d(vertice[anterior(nivel)],0) < UB_local) {
            UB_local = custo + mat_d(vertice[anterior(nivel)],0);
          }
          nivel--;
        }
      }
      else {
        vertice[nivel] = _VAZIO_;
        nivel--;
      }
    }
    sols_d[idx] = qtd_solucoes_thread;
    melhorSol_d[idx] = UB_local;
  }
}



int callCompleteEnumStreams(int nivelPreFixos,  int nPreFixos,int inicio, int fim, short *path_h, int *qtd_sols_total){

  int *mat_d;
  int otimo_global = INFINITO;
  int *qtd_threads_streams;
  int qtd_sols_global = 0;
 
  int block_size =192; 
  
  // printf("nPreFIxos: %d", nPreFixos); 

  int *sols_h, *sols_d; 
  int *melhorSol_h, *melhorSol_d; 

  //path_h ja foi passado como parametro
  
  // short * path_h = (short*) malloc(sizeof(short) * nPreFixos * nivelPreFixos);
  short * path_d;

  /* Variaveis para os streams*/
  /* O número de streams será igual ao nPreFixos/4 */
  //const int chunk = 192*10;
  const int chunk = nPreFixos/4; //para instancia 13: 2970
  //const int numStreams = nPreFixos / chunk + (nPreFixos % chunk == 0 ? 0 : 1); 
  const int numStreams = 4;
  const int num_blocks = chunk/block_size + (chunk % block_size == 0 ? 0 : 1); //13: 16 blocos 
  int resto = 0;
//  printf("nivelPreFixos: %d\nnPreFIxos: %d\nN: %d",nivelPreFixos, nPreFixos,N);
//   printf("chunk: %d\nnStreams: %d", chunk,numStreams);
  resto = (nPreFixos % chunk);

  qtd_threads_streams = (int*)malloc(sizeof(int)*numStreams);



  /*
   * Setando qtd de threads do stream
   * */
  if(numStreams>1){
    for(int i = 0; i<numStreams-1 / block_size;++i){
      qtd_threads_streams[i] = chunk;
    }
    //if(resto>0){
    //  qtd_threads_streams[numStreams-1] = resto;
    //}
  }
  
  //else
  //  qtd_threads_streams[0] = resto;

  CUDA_CHECK_RETURN( cudaMalloc((void **) &path_d, nPreFixos*nivelPreFixos*sizeof(short)));
  sols_h = (int*)malloc(sizeof(int)*nPreFixos);
  melhorSol_h = (int*)malloc(sizeof(int)*nPreFixos); 

  CUDA_CHECK_RETURN( cudaMalloc((void **) &mat_d, N * N * sizeof(int)));
  
  // fillFixedPaths(path_h, nivelPreFixos,inicio,fim); 

  CUDA_CHECK_RETURN( cudaMemcpy(mat_d, mat_h, N * N * sizeof(int), cudaMemcpyHostToDevice));
  for(int i = 0; i<nPreFixos; ++i)
    melhorSol_h[i] = INFINITO;


  CUDA_CHECK_RETURN( cudaMalloc((void **) &melhorSol_d, sizeof(int)*nPreFixos));
  CUDA_CHECK_RETURN( cudaMalloc((void **) &sols_d, sizeof(int)*nPreFixos));

  cudaStream_t vectorOfStreams[numStreams]; 
  
  for(int stream_id=0; stream_id<numStreams; stream_id++) 
      cudaStreamCreate(&vectorOfStreams[stream_id]);
  
  for(int stream_id=0; stream_id<numStreams; stream_id++)  
      cudaMemcpyAsync(&path_d[stream_id*chunk*nivelPreFixos],
            &path_h[stream_id*chunk*nivelPreFixos],
            qtd_threads_streams[stream_id]*sizeof(short)*nivelPreFixos,
            cudaMemcpyHostToDevice,vectorOfStreams[stream_id]);
  for(int stream_id=0; stream_id<numStreams; stream_id++) 
      cudaMemcpyAsync(&melhorSol_d[stream_id*chunk], &melhorSol_h[stream_id*chunk], 
            qtd_threads_streams[stream_id]*sizeof(int),
            cudaMemcpyHostToDevice, vectorOfStreams[stream_id]);
  for(int stream_id=0; stream_id<numStreams; stream_id++) 
      cudaMemcpyAsync(&sols_d[stream_id*chunk], &sols_h[stream_id*chunk], 
            qtd_threads_streams[stream_id]*sizeof(int),
            cudaMemcpyHostToDevice,vectorOfStreams[stream_id]);
  for(int stream_id=0; stream_id<numStreams; stream_id++) 
      dfs_cuda_UB_stream<<<num_blocks,block_size,0,vectorOfStreams[stream_id]>>>
            (N,qtd_threads_streams[stream_id],mat_d,
            &path_d[stream_id*chunk*nivelPreFixos], nivelPreFixos,999999,
            &sols_d[stream_id*chunk],&melhorSol_d[stream_id*chunk]);
  for(int stream_id=0; stream_id<numStreams; stream_id++) 
      cudaMemcpyAsync(&sols_h[stream_id*chunk],&sols_d[stream_id*chunk],
            qtd_threads_streams[stream_id]*sizeof(int),
            cudaMemcpyDeviceToHost,vectorOfStreams[stream_id]);
  for(int stream_id=0; stream_id<numStreams; stream_id++)   
      cudaMemcpyAsync(&melhorSol_h[stream_id*chunk],&melhorSol_d[stream_id*chunk],
            qtd_threads_streams[stream_id]*sizeof(int),
            cudaMemcpyDeviceToHost,vectorOfStreams[stream_id]);
  
  cudaDeviceSynchronize();


  for(int i = 0; i<nPreFixos; ++i){
      qtd_sols_global+=sols_h[i];
      if(melhorSol_h[i]<otimo_global)
        otimo_global = melhorSol_h[i];
  }

  printf("\n\n\n\t niveis preenchidos: %d.\n",nivelPreFixos);

  printf("\t Numero de streams: %d.\n",numStreams);
  printf("\t Tamanho do stream: %d.\n",chunk);
  printf("\nQuantidade de solucoes encontradas: %d.", qtd_sols_global);
  printf("\n\tOtimo global: %d.\n\n", otimo_global);

  CUDA_CHECK_RETURN( cudaFree(mat_d));
  CUDA_CHECK_RETURN( cudaFree(sols_d));
  CUDA_CHECK_RETURN( cudaFree(path_d));
  CUDA_CHECK_RETURN( cudaFree(melhorSol_d));

  *qtd_sols_total = qtd_sols_global;
  
  return otimo_global;
}


// int callCompleteEnumStreams(const int nivelPreFixos, int inicio, int fim){

//   int *mat_d;
//   int otimo_global = INFINITO;
//   int *qtd_threads_streams;
//   int qtd_sols_global = 0;
//   int nPreFixos = calculaNPrefixos(nivelPreFixos,N);
//   int block_size =192; 
  
//   printf("nPreFIxos: %d", nPreFixos); 

//   int *sols_h, *sols_d; 
//   int *melhorSol_h, *melhorSol_d; 
  
//   short * path_h = (short*) malloc(sizeof(short) * nPreFixos * nivelPreFixos);
//   short * path_d;

//   /* Variaveis para os streams*/
//   /* O número de streams será igual ao nPreFixos/4 */
//   //const int chunk = 192*10;
//   const int chunk = nPreFixos/4; //para instancia 13: 2970
//   //const int numStreams = nPreFixos / chunk + (nPreFixos % chunk == 0 ? 0 : 1); 
//   const int numStreams = 4;
//   const int num_blocks = chunk/block_size + (chunk % block_size == 0 ? 0 : 1); //13: 16 blocos 
//   int resto = 0;
// //  printf("nivelPreFixos: %d\nnPreFIxos: %d\nN: %d",nivelPreFixos, nPreFixos,N);
// //   printf("chunk: %d\nnStreams: %d", chunk,numStreams);
//   resto = (nPreFixos % chunk);

//   qtd_threads_streams = (int*)malloc(sizeof(int)*numStreams);

//   /*
//    * Setando qtd de threads do stream
//    * */
//   if(numStreams>1){
//     for(int i = 0; i<numStreams-1 / block_size;++i){
//       qtd_threads_streams[i] = chunk;
//     }
//     //if(resto>0){
//     //  qtd_threads_streams[numStreams-1] = resto;
//     //}
//   }
  
//   //else
//   //  qtd_threads_streams[0] = resto;

//   CUDA_CHECK_RETURN( cudaMalloc((void **) &path_d, nPreFixos*nivelPreFixos*sizeof(short)));
//   sols_h = (int*)malloc(sizeof(int)*nPreFixos);
//   melhorSol_h = (int*)malloc(sizeof(int)*nPreFixos); 

//   CUDA_CHECK_RETURN( cudaMalloc((void **) &mat_d, N * N * sizeof(int)));
  
//   fillFixedPaths(path_h, nivelPreFixos,inicio,fim); 

//   CUDA_CHECK_RETURN( cudaMemcpy(mat_d, mat_h, N * N * sizeof(int), cudaMemcpyHostToDevice));
//   for(int i = 0; i<nPreFixos; ++i)
//     melhorSol_h[i] = INFINITO;


//   CUDA_CHECK_RETURN( cudaMalloc((void **) &melhorSol_d, sizeof(int)*nPreFixos));
//   CUDA_CHECK_RETURN( cudaMalloc((void **) &sols_d, sizeof(int)*nPreFixos));

//   cudaStream_t vectorOfStreams[numStreams]; 
  
//   for(int stream_id=0; stream_id<numStreams; stream_id++) 
//       cudaStreamCreate(&vectorOfStreams[stream_id]);
  
//   for(int stream_id=0; stream_id<numStreams; stream_id++)  
//       cudaMemcpyAsync(&path_d[stream_id*chunk*nivelPreFixos],
//             &path_h[stream_id*chunk*nivelPreFixos],
//             qtd_threads_streams[stream_id]*sizeof(short)*nivelPreFixos,
//             cudaMemcpyHostToDevice,vectorOfStreams[stream_id]);
//   for(int stream_id=0; stream_id<numStreams; stream_id++) 
//       cudaMemcpyAsync(&melhorSol_d[stream_id*chunk], &melhorSol_h[stream_id*chunk], 
//             qtd_threads_streams[stream_id]*sizeof(int),
//             cudaMemcpyHostToDevice, vectorOfStreams[stream_id]);
//   for(int stream_id=0; stream_id<numStreams; stream_id++) 
//       cudaMemcpyAsync(&sols_d[stream_id*chunk], &sols_h[stream_id*chunk], 
//             qtd_threads_streams[stream_id]*sizeof(int),
//             cudaMemcpyHostToDevice,vectorOfStreams[stream_id]);
//   for(int stream_id=0; stream_id<numStreams; stream_id++) 
//       dfs_cuda_UB_stream<<<num_blocks,block_size,0,vectorOfStreams[stream_id]>>>
//             (N,qtd_threads_streams[stream_id],mat_d,
//             &path_d[stream_id*chunk*nivelPreFixos], nivelPreFixos,999999,
//             &sols_d[stream_id*chunk],&melhorSol_d[stream_id*chunk]);
//   for(int stream_id=0; stream_id<numStreams; stream_id++) 
//       cudaMemcpyAsync(&sols_h[stream_id*chunk],&sols_d[stream_id*chunk],
//             qtd_threads_streams[stream_id]*sizeof(int),
//             cudaMemcpyDeviceToHost,vectorOfStreams[stream_id]);
//   for(int stream_id=0; stream_id<numStreams; stream_id++)   
//       cudaMemcpyAsync(&melhorSol_h[stream_id*chunk],&melhorSol_d[stream_id*chunk],
//             qtd_threads_streams[stream_id]*sizeof(int),
//             cudaMemcpyDeviceToHost,vectorOfStreams[stream_id]);
  
//   cudaDeviceSynchronize();

//   for(int i = 0; i<nPreFixos; ++i){
//       qtd_sols_global+=sols_h[i];
//       if(melhorSol_h[i]<otimo_global)
//         otimo_global = melhorSol_h[i];
//   }

//   printf("\n\n\n\t niveis preenchidos: %d.\n",nivelPreFixos);

//   printf("\t Numero de streams: %d.\n",numStreams);
//   printf("\t Tamanho do stream: %d.\n",chunk);
//   printf("\nQuantidade de solucoes encontradas: %d.", qtd_sols_global);
//   printf("\n\tOtimo global: %d.\n\n", otimo_global);

//   CUDA_CHECK_RETURN( cudaFree(mat_d));
//   CUDA_CHECK_RETURN( cudaFree(sols_d));
//   CUDA_CHECK_RETURN( cudaFree(path_d));
//   CUDA_CHECK_RETURN( cudaFree(melhorSol_d));

//   return otimo_global;
// }



int fillFixedPaths(short *preFixo,int nivelPrefixo,int inicio,int fim) {

  printf("\n");


  char flag[20];
  int vertice[20]; 
  int cont = 0;
  int i, nivel;
  bool teste; 

  for (i = 0; i < N; ++i) {
    flag[i] = 0;
    vertice[i] = -1;
  }

  vertice[0] = 0; 

  flag[0] = 1;

  nivel = 1;
  while (nivel >= 1){

    if (vertice[nivel] != -1) {
      flag[vertice[nivel]] = 0;
    }


    if(nivel == 1 ){//assegurando que apenas o intervalo seja utilizado como raiz de nivel 1
        for(int i = 1; i<N;++i){
            if(i<inicio || i>fim)
              flag[i] = 1;
        }

    }


    do {

        vertice[nivel]++;

    } while (vertice[nivel] < N && flag[vertice[nivel]]); //enquanto for menor que N e nao estiver visitado
    

    if(nivel == 1 ){//assegurando que apenas o intervalo seja utilizado como raiz de nivel 1
        for(int i = 1; i<N;++i){
            if(i<inicio || i>fim)
              flag[i] = 0;
        }

    }



    if (vertice[nivel] < N) { 
      
      flag[vertice[nivel]] = 1;
      nivel++;

      if (nivel == nivelPrefixo) {
        for (i = 0; i < nivelPrefixo; ++i) {
          preFixo[cont * nivelPrefixo + i] = vertice[i];
        }
        cont++;
        nivel--;
      }
    } else {
      vertice[nivel] = -1;
      nivel--;
    }
  }

  return cont;
}
