#include "define.h"
#include "structs.h"

extern "C" {
#include "my_cuda.h"
}

texture<int> texLUT;

THREADFAULTPTR dev_table = NULL;
//THREADFAULTPTR dev_table2 = NULL;
//THREADFAULTPTR dev_table3 = NULL;
RESULTPTR dev_res = NULL;
//RESULTPTR Goodsim = NULL;
int *dev_LUT = NULL;
int *cuda_vecs = NULL;
int Cuda_index = 0;
//int total=0;


__global__ void fill_struct_kernel(THREADFAULTPTR dev_table, int* Vectors, int offset, int length, int pos){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		//THREADTYPE data = dev_table[tid];
		int loc_pos = pos*length;
		dev_table[tid+loc_pos].offset = offset;
		dev_table[tid+loc_pos].input[0] = Vectors[tid];
		//an douleyei to memset tote poulo ayta
		//dev_table[tid].input[1] = 0;
		//dev_table[tid].input[2] = 0;
		//dev_table[tid].input[3] = 0;
		dev_table[tid+loc_pos].m0 = 1;
		dev_table[tid+loc_pos].m1 = 0;
	}
}


__global__ void fill_struct_kernel1(THREADFAULTPTR dev_table, RESULTPTR dev_res, int offset, int length, int pos, int read_mem, int k){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		//THREADTYPE data = dev_table[tid];
		int loc_pos = pos*length;
		dev_table[tid+loc_pos].offset = offset;
		dev_table[tid+loc_pos].input[k] = dev_res[read_mem].output;
		dev_table[tid+loc_pos].m0 = 1;
		dev_table[tid+loc_pos].m1 = 0;
	}
}



__global__ void logic_simulation_kernel(THREADFAULTPTR dev_table, RESULTPTR dev_res, int length, int pos){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	//elegxos an perasoume ta osa steilame
	//xreiazomaste kai allon ena elegxo an ayta pou exoume steilei einai pio polla apo ta nhmata
	if (tid < length) {
		THREADFAULTYPE data = dev_table[tid+pos];
		int index = data.offset + data.input[0] + data.input[1]*2 + data.input[2]*4 + data.input[3]*8;
		int output = tex1Dfetch(texLUT,index);
		dev_res[tid+pos].output = output;
	}
}


__global__ void fault_injection_kernel(THREADFAULTPTR dev_table,RESULTPTR dev_res,int length){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		THREADFAULTYPE data = dev_table[tid];
		int index = data.offset + data.input[0] + data.input[1]*2 + data.input[2]*4 + data.input[3]*8;
		int output = tex1Dfetch(texLUT,index);
		dev_res[tid].output = (output && data.m0) || data.m1;
	}
}


__global__ void fault_detection_kernel(THREADFAULTPTR dev_table,RESULTPTR dev_res,RESULTPTR Good,int length){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		THREADFAULTYPE data = dev_table[tid];
		RESULTYPE data1 = Good[tid];
		int index = data.offset + data.input[0] + data.input[1]*2 + data.input[2]*4 + data.input[3]*8;
		int output = tex1Dfetch(texLUT,index);
		int output1 = data1.output;
		dev_res[tid].output = output ^ output1;
	}
}







extern "C" void device_allocations()
{
	//allocate memory for all the gates for logic sim
	//isws prepei na megalwsei gia na mhn ksanadesmeuoume mnhmh gia to fault sim
	size_t size = patterns*nog;

	//int dev;
	//HANDLE_ERROR( cudaGetDevice (&dev));
	//printf("ID of current CUDA device: %d\n",dev);

	HANDLE_ERROR( cudaSetDevice (2));
	//HANDLE_ERROR( cudaGetDevice (&dev));
	//printf("ID of current CUDA device: %d\n",dev);

	//allocations for texture memory
	HANDLE_ERROR( cudaMalloc( (void**)&dev_LUT, 182*sizeof(int)));
	//allocations for cuda_vectors
	HANDLE_ERROR( cudaMalloc( (void**)&cuda_vecs, (patterns*levels[0]) * sizeof(int) ));
    //allocations cuda table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_table, size*sizeof(THREADFAULTYPE)));
	// check the cuda mem set with a memcpy ok -----------------------------------------------
	HANDLE_ERROR(cudaMemset(dev_table, 0,size*sizeof(THREADFAULTYPE)));
	//allocations for result table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_res, size*sizeof(int)));

	//HANDLE_ERROR( cudaMemcpy(cuda_table, dev_table, size*sizeof(THREADFAULTYPE),cudaMemcpyDeviceToHost ));

	//fill and bind the texture
	HANDLE_ERROR( cudaMemcpy(dev_LUT, LUT, 182*sizeof(int), cudaMemcpyHostToDevice));
	HANDLE_ERROR( cudaBindTexture( NULL,texLUT,dev_LUT, 182*sizeof(int)));
	//fill the Cuda_vecs
	HANDLE_ERROR( cudaMemcpy(cuda_vecs, cuda_vectors, (patterns*levels[0]) * sizeof(int) , cudaMemcpyHostToDevice));
}



extern "C" void init_first_level()
{
	int offset, i, threads, blocks;
	int length = patterns * levels[0];
	//GATEPTR cg;

	threads = 128;
	blocks = ( patterns + (threads-1))/threads;
	if (blocks < 200) {
		threads = 64;
		blocks = ( patterns + (threads-1))/threads;
	}

	for (i = 0; i<levels[0]; i++) {
		//call kernel for each gate
		//cg = event_list[0].list[i];
		offset = PI;
		//printf("i am %s with %d offset\n", cg->symbol->symbol,offset);

		//fill the first level of the array
		fill_struct_kernel<<<blocks,threads>>>(dev_table, cuda_vecs, offset, patterns, i);
	}

	threads = 128;
	blocks = ( length + (threads-1))/threads;
	if (blocks < 200) {
		threads = 64;
		blocks = ( length + (threads-1))/threads;
	}

	//do the first logic sim
	logic_simulation_kernel<<<blocks,threads>>>(dev_table, dev_res, length, Cuda_index);
	Cuda_index = length;
}



extern "C" void init_any_level()
{
	int i, j, k, offset;
	int epipedo, gatepos, array;
	int threads, blocks;
	int pos = 0;
	int length;
	GATEPTR cg, hg;

	pos = levels[0];

	//Gia ola ta epipeda tou kyklwmatos
	for (i = 1; i< (maxlevel-1); i++){



	length = patterns * levels[i];

	threads = 128;
	blocks = ( patterns + (threads-1))/threads;
	if (blocks < 200) {
		threads = 64;
		blocks = ( patterns + (threads-1))/threads;
	}

	for (j = 0; j< levels[i]; j++){
		cg = event_list[i].list[j];
		offset = find_offset(cg);
		//gia na to dwsoyme ston kernel fill
		pos++;
		//printf("i am %s with %d offset\n", cg->symbol->symbol,offset);
		for (k = 0; k<cg->ninput; k++) {
			hg = cg->inlis[k];
			array = hg->index * patterns;

			fill_struct_kernel1<<<blocks,threads>>>(dev_table, dev_res, offset, patterns, pos, array, k);
		}
	}

	threads = 128;
	blocks = ( length + (threads-1))/threads;
	if (blocks < 200) {
		threads = 64;
		blocks = ( length + (threads-1))/threads;
	}

	//do the first logic sim
	logic_simulation_kernel<<<blocks,threads>>>(dev_table, dev_res, length, Cuda_index);
	Cuda_index = Cuda_index + length;

	}

	HANDLE_ERROR( cudaMemcpy(result_tables, dev_res, patterns*nog* sizeof(int) , cudaMemcpyDeviceToHost));
}





/*void init_any_level(int lev,THREADPTR table)
{
	GATEPTR cg,hg,pg;
	int i,j,k,l,gatepos,m;
	register int pos;
	int epipedo;
	int offset,array,arr;

	//for all the gates of the lev level
	for (i = 0; i<=event_list[lev].last; i++) {
		cg = event_list[lev].list[i];

		//offset = find_offset(cg);
		//printf("%s\n",cg->symbol->symbol);
		//koita tis inlist kai pare th thesh twn pulwn apo tis opoies tha diavasoume

		for (k = 0; k<cg->ninput; k++) {
			hg = cg->inlis[k];
			epipedo = hg->level;
			gatepos = hg->level_pos;

			//opts
			array=gatepos*patterns;
			arr = i*patterns;

			//for all the patterns for this gate
			for ( j = 0; j<patterns; j++) {
				pos = arr + j;
				table[pos].offset = cg->offset;
				table[pos].input[k] = result_tables[epipedo][array+j].output;
			}
		}
	}
}*/




extern "C" int find_offset (GATEPTR cg)
{
	int inputs, offset, fn;

	inputs = cg->ninput;
	fn = cg->fn;

	switch (fn) {
		case AND:
			if (inputs == 2) offset = AND2;
			else if (inputs == 3) offset = AND3;
			else if (inputs == 4) offset = AND4;
			else if (inputs == 5) offset = AND5;
			break;
		case NAND:
			if (inputs == 2) offset = NAND2;
			else if (inputs == 3) offset = NAND3;
			else if (inputs == 4) offset = NAND4;
			break;
		case OR:
			if (inputs == 2) offset = OR2;
			else if (inputs == 3) offset = OR3;
			else if (inputs == 4) offset = OR4;
			else if (inputs == 5) offset = OR5;
			break;
		case NOR:
			if (inputs == 2) offset = NOR2;
			else if (inputs == 3) offset = NOR3;
			else if (inputs == 4) offset = NOR4;
			break;
		case PO: offset = PO;
	}

	return (offset);

}



/*
extern "C" void dummy_gpu(int level){
	//int i;
	int blocks;
	int threads;


	//size_t size = patterns*levels[0]*sizeof(THREADTYPE);
	int length = patterns*levels[level];
	//total=total+length;
	//printf("Length for logic sim epipedo %d %d\n",level,length);

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
}


extern "C" void dummy_gpu2(int level){
	//int i;
	int blocks;
	int threads;

	int length = no_po_faults*patterns;
	if (level > 0) length = next_level_length * patterns;
	//total=total+length;
	//printf("CUDA2 length gia epipedo %d %d\n",level,length);

	//copy from Ram to device
	HANDLE_ERROR( cudaMemcpy(dev_table2, fault_tables[level], length*sizeof(THREADFAULTYPE), cudaMemcpyHostToDevice));

	//printf("length of array=%d\n",length);
	//printf("maxgates=%d\n",maxgates);

	threads = 128;
	blocks = (length+(threads-1))/threads;
	if (blocks < 200) {
		threads = 64;
		blocks = (length+(threads-1))/threads;
	}
   // printf("The number of blocks %d\n",blocks);
	fault_injection_kernel<<<blocks,threads>>>(dev_table2,dev_res,length);
	

	HANDLE_ERROR( cudaMemcpy(fault_result_tables[level], dev_res,length*sizeof(int) , cudaMemcpyDeviceToHost));


    //for (i = 0; i<length; i++ )
    	//printf("%d",fault_result_tables[level][i]);
}



extern "C" void dummy_gpu3(){
	//int i;
	int blocks;
	int threads;

	int length = detect_index*patterns;
	//printf("CUDA3 length is %d\n",length);

	//printf("I am here\n");
	//copy from Ram to device
	HANDLE_ERROR( cudaMemcpy(dev_table3, detect_tables, length*sizeof(THREADFAULTYPE), cudaMemcpyHostToDevice));
	HANDLE_ERROR( cudaMemcpy(Goodsim, GoodSim, length*sizeof(int), cudaMemcpyHostToDevice));

	//printf("length of array=%d\n",length);
	//printf("maxgates=%d\n",maxgates);

	threads = 128;
	blocks = (length+(threads-1))/threads;
	if (blocks < 200) {
		threads = 64;
		blocks = (length+(threads-1))/threads;
	}
   // printf("The number of blocks %d\n",blocks);
	fault_detection_kernel<<<blocks,threads>>>(dev_table3,dev_res,Goodsim,length);


	HANDLE_ERROR( cudaMemcpy(Final, dev_res,length*sizeof(int) , cudaMemcpyDeviceToHost));

    //for(i = 0; i<length; i++)printf("%d",GoodSim[i]);

    printf("length is %d\n",length);

    //for (i = 0; i<length; i++ )
    	//printf("%d",Final[i]);
}



extern "C" void device_allocations()
{
	size_t size = patterns*maxgates;
	//int dev;

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


extern "C" void device_allocations2()
{
	size_t size = 100000000;

	//HANDLE_ERROR( cudaSetDevice (2));

    //allocations cuda table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_table2, size*sizeof(THREADFAULTYPE)));
	//allocations for result table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_res, size*sizeof(int)));
}


extern "C" void alloc(){
	size_t size = 100000000;
	HANDLE_ERROR( cudaMalloc( (void**)&dev_table2, size*sizeof(THREADTYPE)));
}


extern "C" void device_allocations3()
{
	int length = detect_index*patterns;
	//int length =100000000;

	//HANDLE_ERROR( cudaSetDevice (2));

    //allocations cuda table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_table3, length*sizeof(THREADFAULTYPE)));
	HANDLE_ERROR( cudaMalloc( (void**)&Goodsim, length*sizeof(int)));
	//allocations for result table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_res, length*sizeof(int)));
}


extern "C" void device_deallocations()
{
    // Free device global memory
    HANDLE_ERROR( cudaFree(dev_table));
    HANDLE_ERROR( cudaFree(dev_res));
    //HANDLE_ERROR( cudaDeviceReset());

}


extern "C" void dealloc(){
	HANDLE_ERROR( cudaFree(dev_table2));
}


extern "C" void device_deallocations2()
{
    // Free device global memory
    HANDLE_ERROR( cudaFree(dev_table2));
    HANDLE_ERROR( cudaFree(dev_res));
    //HANDLE_ERROR( cudaDeviceReset());
}

extern "C" void device_deallocations3()
{
    // Free device global memory
    HANDLE_ERROR( cudaFree(dev_table3));
    HANDLE_ERROR( cudaFree(dev_res));
    HANDLE_ERROR( cudaDeviceReset());
}
*/
