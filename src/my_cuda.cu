#include "define.h"
#include "structs.h"

extern "C" {
#include "my_cuda.h"
}

texture<int> texLUT;

THREADPTR dev_table = NULL;
RESULTPTR dev_res = NULL;
int *dev_LUT = NULL;

__global__ void logic_simulation_kernel(THREADPTR dev_table,RESULTPTR dev_res,int length){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		THREADTYPE data = dev_table[tid];
		int index = data.offset + data.input[0] + data.input[1]*2 + data.input[2]*4 + data.input[3]*8;
		int output = tex1Dfetch(texLUT,index);
		dev_res[tid].output = output;
	}
}


extern "C" void dummy_gpu(int level){
	//int i;
	int blocks;
	int threads;

	//size_t size = patterns*levels[0]*sizeof(THREADTYPE);
	int length = patterns*levels[level];
	//printf("Length is %d\n",length);

	//device_allocations();

	//copy from Ram to device
	HANDLE_ERROR( cudaMemcpy(dev_table, cuda_tables[level], length*sizeof(THREADTYPE), cudaMemcpyHostToDevice));

	//printf("length of array=%d\n",length);
	//printf("maxgates=%d\n",maxgates);

	threads = 128;
	blocks = (length+(threads-1))/threads;
	if (blocks < 200) {
		threads = 64;
		blocks = (length+(threads-1))/threads;
	}
   // printf("The number of blocks %d\n",blocks);
    logic_simulation_kernel<<<blocks,threads>>>(dev_table,dev_res,length);


	HANDLE_ERROR( cudaMemcpy(result_tables[level], dev_res,length*sizeof(int) , cudaMemcpyDeviceToHost));


    //for (i = 0; i<length; i++ )
    	//printf("%d",result_tables[level][i]);
    //printf("\n");

    // Free device global memory
    //HANDLE_ERROR( cudaFree(dev_table));
    //HANDLE_ERROR( cudaFree(dev_res));
    //HANDLE_ERROR( cudaDeviceReset());
}



extern "C" void device_allocations()
{
	size_t size = patterns*maxgates;
	int dev;

	//HANDLE_ERROR( cudaGetDevice (&dev));
	//printf("ID of current CUDA device: %d\n",dev);
	HANDLE_ERROR( cudaSetDevice (2));
	//HANDLE_ERROR( cudaGetDevice (&dev));
	//printf("ID of current CUDA device: %d\n",dev);

	//allocations for texture memory
	HANDLE_ERROR( cudaMalloc( (void**)&dev_LUT, 182*sizeof(int)));
    //allocations cuda table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_table, size*sizeof(THREADTYPE)));
	//allocations for result table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_res, size*sizeof(int)));
	//fill and bind the texture
	HANDLE_ERROR( cudaMemcpy(dev_LUT, LUT, 182*sizeof(int), cudaMemcpyHostToDevice));
	HANDLE_ERROR( cudaBindTexture( NULL,texLUT,dev_LUT, 182*sizeof(int)));
}
