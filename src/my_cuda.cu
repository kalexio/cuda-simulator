#include <cuda_runtime.h>
#include "define.h"
#include "structs.h"

extern "C" {
#include "my_cuda.h"
}

texture<int> texLUT;


__global__ void logic_simulation_kernel(THREADPTR dev_table,RESULTPTR dev_res,int length){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		THREADTYPE data = dev_table[tid];
		int index = data.offset + data.input[0] + data.input[1]*2 + data.input[2]*4 + data.input[3]*8;
		int output = tex1D(texLUT,index);
		dev_res[tid].output = output;
	}
}


extern "C" void dummy_gpu(){
	//int i;
	int blocks;
	THREADPTR dev_table = NULL;
	RESULTPTR dev_res = NULL;
	int *dev_LUT = NULL;
	size_t size = patterns*levels[0]*sizeof(THREADTYPE);
	int length = patterns*levels[0];
	cudaError_t err = cudaSuccess;


	//cudaDeviceProp prop;

	//if(prop.deviceOverlap)
		//printf(" speed up from streams :)\n");

	// texture memory
	err = cudaMalloc( (void**)&dev_LUT, 182*sizeof(int));
	if (err != cudaSuccess)
	{
		fprintf(stderr, "Failed to allocate device memory for LUT (error code %s)!\n", cudaGetErrorString(err));
	    exit(EXIT_FAILURE);
	}

	printf("LUT[0] = %d\n",LUT[0]);
	printf("Copy input data from the host memory LUT to the CUDA device dev_LUT\n");
	err = cudaMemcpy(dev_LUT, LUT, 182*sizeof(int), cudaMemcpyHostToDevice);
	if (err != cudaSuccess)
	{
		fprintf(stderr, "Failed to copy vector A from host to device (error code %s)!\n", cudaGetErrorString(err));
	    exit(EXIT_FAILURE);
	}

	err = cudaBindTexture( NULL,texLUT,dev_LUT, 182*sizeof(int));
	if (err != cudaSuccess)
	{
	    fprintf(stderr, "Failed to cudabind (error code %s)!\n", cudaGetErrorString(err));
	    exit(EXIT_FAILURE);
	}

    // cuda table
	err = cudaMalloc( (void**)&dev_table, size);
	if (err != cudaSuccess)
	{
	    fprintf(stderr, "Failed to allocate device memory (error code %s)!\n", cudaGetErrorString(err));
	    exit(EXIT_FAILURE);
	}

	printf("Copy input data from the host memory to the CUDA device\n");
	err = cudaMemcpy(dev_table, cuda_tables[0], size, cudaMemcpyHostToDevice);
	if (err != cudaSuccess)
	{
	    fprintf(stderr, "Failed to copy vector A from host to device (error code %s)!\n", cudaGetErrorString(err));
	    exit(EXIT_FAILURE);
	}

	//res table
	err = cudaMalloc( (void**)&dev_res, patterns*levels[0]*sizeof(int));
	if (err != cudaSuccess)
	{
	    fprintf(stderr, "Failed to allocate device memory (error code %s)!\n", cudaGetErrorString(err));
	    exit(EXIT_FAILURE);
	}

	printf("%d\n",patterns*levels[0]);
	blocks = (patterns*levels[0]+127)/128;
    logic_simulation_kernel<<<blocks,128>>>(dev_table,dev_res,length);

	printf("Copy input data from the device memory to the host\n");
	err = cudaMemcpy(result_tables[0], dev_res,patterns*levels[0]*sizeof(int) , cudaMemcpyDeviceToHost);
	if (err != cudaSuccess)
	{
	    fprintf(stderr, "Failed to copy the results from device to host (error code %s)!\n", cudaGetErrorString(err));
	    exit(EXIT_FAILURE);
	}


    printf("END\n");

    //for (i = 0; i<54; i++ )
    	//printf("%d",result_tables[0][i]);

    // Free device global memory
    err = cudaFree(dev_table);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to free device table (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    err = cudaFree(dev_res);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to free device result (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    err = cudaDeviceReset();

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to deinitialize the device! error=%s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }


}
