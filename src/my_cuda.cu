#include "define.h"
#include "structs.h"

extern "C" {
#include "my_cuda.h"
}

texture<int> texLUT;

THREADFAULTPTR dev_table = NULL;
THREADFAULTPTR dev_table2 = NULL;
//THREADFAULTPTR dev_table3 = NULL;
RESULTPTR dev_res = NULL;
RESULTPTR dev_res2 = NULL;
//RESULTPTR Goodsim = NULL;
int *dev_LUT = NULL;
int *cuda_vecs = NULL;
int Cuda_index = 0;
int real_faults = -1;
//int total=0;


__global__ void fill_struct_kernel(THREADFAULTPTR dev_table, int* Vectors, int offset, int length, int pos){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid+pos;
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[0] = Vectors[thread_id];
		dev_table[thread_id].m0 = 1;
		dev_table[thread_id].m1 = 0;
	}
}


__global__ void fill_struct_kernel1(THREADFAULTPTR dev_table, RESULTPTR dev_res, int offset, int length, int pos, int read_mem, int k){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid+pos;
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[k] = dev_res[tid+read_mem].output;
		dev_table[thread_id].m0 = 1;
		dev_table[thread_id].m1 = 0;
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




__global__ void fill_fault_struct_kernel_PI(THREADFAULTPTR dev_table, int* Vectors, int offset, int length, int pos, int inj_bit0, int inj_bit1, int gatepos){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid+pos;
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[0] = Vectors[tid+gatepos];
		dev_table[thread_id].m0 = inj_bit0;
		dev_table[thread_id].m1 = inj_bit1;
	}
}

__global__ void fill_fault_struct_kernel_notPI(THREADFAULTPTR dev_table, RESULTPTR dev_res, int offset, int length, int pos, int inj_bit0, int inj_bit1, int gatepos, int k){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid+pos;
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[k] = dev_res[tid+gatepos].output;
		dev_table[thread_id].m0 = inj_bit0;
		dev_table[thread_id].m1 = inj_bit1;
	}
}


__global__ void fill_fault_struct_kernel_Paths(THREADFAULTPTR dev_table, RESULTPTR dev_res, int offset, int length, int pos, int gatepos, int k){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid + gatepos;
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[k] = dev_res[tid+pos].output;
		dev_table[thread_id].m0 = 1;
		dev_table[thread_id].m1 = 0;
	}
}

__global__ void fault_injection_kernel(THREADFAULTPTR dev_table2, RESULTPTR dev_res2, int length, int pos){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		THREADFAULTYPE data = dev_table2[tid+pos];
		int index = data.offset + data.input[0] + data.input[1]*2 + data.input[2]*4 + data.input[3]*8;
		int output = tex1Dfetch(texLUT,index);
		dev_res2[tid+pos].output = (output & data.m0) | data.m1;
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

	size_t size = patterns*total_gates;
	//int size = 1000000;

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
	HANDLE_ERROR(cudaMemset(dev_table, 0, size*sizeof(THREADFAULTYPE)));
	//allocations for result table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_res, size*sizeof(int)));


	//fill and bind the texture
	HANDLE_ERROR( cudaMemcpy(dev_LUT, LUT, 182*sizeof(int), cudaMemcpyHostToDevice));
	HANDLE_ERROR( cudaBindTexture( NULL,texLUT,dev_LUT, 182*sizeof(int)));
	//fill the Cuda_vecs
	HANDLE_ERROR( cudaMemcpy(cuda_vecs, cuda_vectors, (patterns*levels[0]) * sizeof(int) , cudaMemcpyHostToDevice));
}



extern "C" void init_first_level()
{
	int offset, i, threads, blocks;
	int length, pos;

	threads = 128;
	blocks = ( patterns + (threads-1))/threads;
	if (blocks < 200) {
		threads = 64;
		blocks = ( patterns + (threads-1))/threads;
	}

	offset = PI;
	for (i = 0; i<levels[0]; i++) {
		pos = i * patterns;
		fill_struct_kernel<<<blocks,threads>>>(dev_table, cuda_vecs, offset, patterns, pos);
	}
	threads = 128;
	length = patterns * levels[0];
	blocks = ( length + (threads-1))/threads;
	if (blocks < 200) {
		threads = 64;
		blocks = ( length + (threads-1))/threads;
	}
	logic_simulation_kernel<<<blocks,threads>>>(dev_table, dev_res, length, Cuda_index);
	Cuda_index = length;
}



extern "C" void init_any_level()
{
	int i, j, k, offset, array;
	int threads, blocks, pos1, length;
	int pos = 0;
	GATEPTR cg, hg;

	pos = levels[0]-1;

	//Gia ola ta epipeda tou kyklwmatos
	//mhpws thelei -2 anti gia -1????
	for (i = 1; i< (maxlevel-1); i++){

		threads = 128;
		blocks = ( patterns + (threads-1))/threads;
		if (blocks < 200) {
			threads = 64;
			blocks = ( patterns + (threads-1))/threads;
		}

		for (j = 0; j< levels[i]; j++){
			cg = event_list[i].list[j];
			offset = find_offset(cg);
			pos++;
			pos1 = pos*patterns;
			//printf("i am %s with %d offset\n", cg->symbol->symbol,offset);
			for (k = 0; k<cg->ninput; k++) {
				hg = cg->inlis[k];
				array = hg->index * patterns;
				fill_struct_kernel1<<<blocks,threads>>>(dev_table, dev_res, offset, patterns, pos1, array, k);
			}
		}

		threads = 128;
		length = patterns * levels[i];
		blocks = ( length + (threads-1))/threads;
		if (blocks < 200) {
			threads = 64;
			blocks = ( length + (threads-1))/threads;
		}

		logic_simulation_kernel<<<blocks,threads>>>(dev_table, dev_res, length, Cuda_index);
		Cuda_index = Cuda_index + length;

	}
	//HANDLE_ERROR( cudaMemcpy(result_tables, dev_res, Cuda_index* sizeof(int) , cudaMemcpyDeviceToHost));
	HANDLE_ERROR( cudaFree(dev_table));
}



extern "C" void device_allocations2()
{
	size_t size = 126000000;

	//HANDLE_ERROR( cudaSetDevice (2));

    //allocations cuda table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_table2, size*sizeof(THREADFAULTYPE)));
	//allocations for result table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_res2, size*sizeof(int)));
}



extern "C" void fault_init_first_level(){
		int i, k;
		GATEPTR cg, hg;
		int inj_bit0 = 1;
		int inj_bit1 = 0;
		int blocks, threads, length;
		int  gatepos, array, arr;
		//int real_faults = -1;

		threads = 256;
		blocks = ( patterns + (threads-1))/threads;
		//if (blocks < 200) {
			//threads = 64;
			//blocks = ( patterns + (threads-1))/threads;
		//}

		for (i = 0; i<total_faults; i++){
			//vriskw to offset ths pulhs kai ta injection bits eite einai PI PO etc
			cg = fault_list[i].gate;
			cg->TFO_list[i] = 1;

			if (fault_list[i].SA == 0) {
				inj_bit0 = 0;
				inj_bit1 = 0;
			}
			else inj_bit1 = 1;

			if ( cg->outlis[0]->fn != PO ) {
				real_faults++;
				//thesh stou pinakes twn faults
				cg->fault_level[i] = 0;
				cg->flevel_pos[i] = real_faults;

				if (cg->fn != PI) {
					for (k = 0; k<cg->ninput; k++) {
						hg = cg->inlis[k];
						array = hg->index * patterns;
						arr = real_faults*patterns;
						//printf("%s me index %d  ",hg->symbol->symbol,hg->index);

						fill_fault_struct_kernel_notPI<<<blocks,threads>>>(dev_table2, dev_res, cg->offset, patterns, arr, inj_bit0, inj_bit1, array, k);

					}
				}

				else {
					//Einai PI
					gatepos = cg->level_pos*patterns;
					//printf("%s %d ",cg->symbol->symbol,cg->level_pos);
					arr = real_faults*patterns;

					fill_fault_struct_kernel_PI<<<blocks,threads>>>(dev_table2, cuda_vecs, PI, patterns, arr, inj_bit0, inj_bit1, gatepos);
			   }

			}

			else {
				fault_list[i].end = 2;
			}//end of else

		}//end for faults

		//Call fault injection

		Cuda_index = 0;
		length = real_faults*patterns;
		printf("lenth in first level %d\n",length);
		threads = 512;
		blocks = ( length + (threads-1))/threads;
		fault_injection_kernel<<<blocks,threads>>>(dev_table2, dev_res2, length, Cuda_index);
		Cuda_index = length;
}


extern "C" void fault_init_any_level(){
	int i, k;
	GATEPTR cg, hg;
	int  array, arr;
	int threads, blocks, length;
	//int real_faults = -1;
	int counter = -1;

	threads = 256;
	blocks = ( patterns + (threads-1))/threads;

	for (i = 0; i<total_faults; i++){
		if (fault_list[i].end != 1) {
			if(fault_list[i].TFO_stack.list[fault_list[i].TFO_stack.last]->outlis[0]->fn == PO){
				fault_list[i].end = 2;
			}
			//not PO yet
			else{
				while (fault_list[i].affected_gates > 0){
					fault_list[i].affected_gates--;
					cg = fault_list[i].TFO_stack.list[(fault_list[i].TFO_stack.last)--];
					real_faults++;
					counter++;

					//cg->fault_level[i] = loop;
					cg->flevel_pos[i] = real_faults;

					for (k = 0; k<cg->ninput; k++){
						hg = cg->inlis[k];

						//den einai sto path ara diavase apo to non fault table
						if (hg->TFO_list[i] != 1){
							//from where it reads
							array = hg->index*patterns;
							//to where it will write
							arr = real_faults*patterns;

							//CALL KERNEL
							fill_fault_struct_kernel_Paths<<<blocks,threads>>>(dev_table2, dev_res, cg->offset,patterns,array,arr,k);

						}//end of if path
						else{
							//from where it reads
							array = hg->flevel_pos[i]*patterns;
							//to where it will write
							arr = real_faults*patterns;

							//CALL KERNEL
							fill_fault_struct_kernel_Paths<<<blocks,threads>>>(dev_table2, dev_res2, cg->offset,patterns,array,arr,k);

						}//end of else path

					}//end of inputs

				}//end of while

			}//end of else

		}//end of fault_list.end != 1
	}//end of total faults

	length = counter*patterns;
	threads = 512;
	blocks = ( length + (threads-1))/threads;
	fault_injection_kernel<<<blocks,threads>>>(dev_table2, dev_res2, length, Cuda_index);
	Cuda_index = Cuda_index + length;
	printf("lenth %d\n",Cuda_index);

}


extern "C" void device_deallocations2()
{
    // Free device global memory
    HANDLE_ERROR( cudaFree(dev_table2));
    HANDLE_ERROR( cudaFree(dev_LUT));
    HANDLE_ERROR( cudaFree(cuda_vecs));
    HANDLE_ERROR( cudaFree(dev_res2));
    HANDLE_ERROR( cudaFree(dev_res));
    HANDLE_ERROR( cudaDeviceReset());

}


extern "C" int find_offset (GATEPTR cg)
{
	int inputs, offset, fn;

	inputs = cg->ninput;
	fn = cg->fn;

	switch (fn) {
		case PI: offset = 0;
			break;
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
