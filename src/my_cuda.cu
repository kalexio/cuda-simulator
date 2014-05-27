#include <cuda_runtime.h>

extern "C" {
#include "my_cuda.h"
}
#include <stdio.h>

__global__ void dummy_gpu_kernel(int a, int b, int *c){
	*c = a + b;
}


extern "C" void dummy_gpu(){
   int c;
   int *dev_c;
   cudaMalloc( (void**)&dev_c, sizeof(int));
   dummy_gpu_kernel<<<1,1>>>(2,7,dev_c);
   cudaMemcpy(&c,dev_c,sizeof(int),cudaMemcpyDeviceToHost);
   printf("2 + 7 = %d\n",c);
   printf("executed!\n");
   cudaFree(dev_c);
}
