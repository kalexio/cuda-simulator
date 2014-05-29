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
		int output = tex1Dfetch(texLUT,index);
		dev_res[tid].output = output;
	}
}


extern "C" void dummy_gpu(){
	int i;
	int blocks;
	THREADPTR dev_table = NULL;
	RESULTPTR dev_res = NULL;
	int *dev_LUT = NULL;
	size_t size = patterns*levels[0]*sizeof(THREADTYPE);
	int length = patterns*levels[0];




	// texture memory
	HANDLE_ERROR( cudaMalloc( (void**)&dev_LUT, 182*sizeof(int)));

	printf("LUT[0] = %d\n",LUT[0]);

	HANDLE_ERROR( cudaMemcpy(dev_LUT, LUT, 182*sizeof(int), cudaMemcpyHostToDevice));


	HANDLE_ERROR( cudaBindTexture( NULL,texLUT,dev_LUT, 182*sizeof(int)));


    // cuda table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_table, size));

	HANDLE_ERROR( cudaMemcpy(dev_table, cuda_tables[0], size, cudaMemcpyHostToDevice));

	//res table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_res, patterns*levels[0]*sizeof(int)));

	printf("%d\n",patterns*levels[0]);
	blocks = (patterns*levels[0]+127)/128;
    logic_simulation_kernel<<<blocks,128>>>(dev_table,dev_res,length);


	HANDLE_ERROR( cudaMemcpy(result_tables[0], dev_res,patterns*levels[0]*sizeof(int) , cudaMemcpyDeviceToHost));


    for (i = 0; i<54; i++ )
    	printf("%d",result_tables[0][i]);

    // Free device global memory
    HANDLE_ERROR( cudaFree(dev_table));
    HANDLE_ERROR( cudaFree(dev_res));
    HANDLE_ERROR( cudaDeviceReset());
}
