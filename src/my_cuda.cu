#include "define.h"
#include "structs.h"

extern "C" {
#include "my_cuda.h"
}

texture<int> texLUT;

THREADFAULTPTR dev_table = NULL;
THREADFAULTPTR dev_table2 = NULL;
THREADFAULTPTR dev_table3 = NULL;
RESULTPTR dev_res = NULL;
RESULTPTR dev_res2 = NULL;
RESULTPTR Goodsim = NULL;
RESULTPTR Detection_table = NULL;
int *dev_LUT = NULL;
int *cuda_vecs = NULL;
int Cuda_index = 0;
int real_faults = -1;
int *patterns_positions;
//int total=0;


__global__ void fill_struct_kernel(THREADFAULTPTR dev_table, int* Vectors, int offset, int length, int pos){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid+pos;
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[0] = Vectors[thread_id];
		dev_table[thread_id].m0 = 1;
		//dev_table[thread_id].m1 = 0;
	}
}


__global__ void fill_struct_kernel1(THREADFAULTPTR dev_table, RESULTPTR dev_res, int offset, int length, int pos, int read_mem, int k){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid+pos;
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[k] = dev_res[tid+read_mem].output;
		dev_table[thread_id].m0 = 1;
		//dev_table[thread_id].m1 = 0;
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




__global__ void fill_fault_struct_kernel_PI(THREADFAULTPTR dev_table, int* Vectors, int offset, int length, int pos, int inj_bit0, int inj_bit1, int gatepos,int *patterns_positions){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid+pos;
		int index = patterns_positions[thread_id];
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[0] = Vectors[index];
		dev_table[thread_id].m0 = inj_bit0;
		dev_table[thread_id].m1 = inj_bit1;
	}
}

__global__ void fill_fault_struct_kernel_notPI(THREADFAULTPTR dev_table, RESULTPTR dev_res, int offset, int length, int pos, int inj_bit0, int inj_bit1, int gatepos, int k, int *patterns_positions){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid+pos;
		int index = patterns_positions[thread_id];
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[k] = dev_res[index+gatepos].output;
		dev_table[thread_id].m0 = inj_bit0;
		dev_table[thread_id].m1 = inj_bit1;
	}
}

__global__ void fill_fault_struct_kernel_Paths(THREADFAULTPTR dev_table, RESULTPTR dev_res, int offset, int length, int pos, int gatepos, int k, int *patterns_positions,int until_now){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid + gatepos;
		int index = patterns_positions[tid + until_now];
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[k] = dev_res[index+pos].output;
		//exei ginei memset
		dev_table[thread_id].m0 = 1;
		//dev_table[thread_id].m1 = 0;
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


__global__ void fill_detetection_struct(THREADFAULTPTR dev_table, RESULTPTR dev_res,int offset, int length, int pos, int gatepos,int k, int *patterns_positions,int until_now,int good_index,RESULTPTR Goodsim,RESULTPTR devres){
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid < length) {
		int thread_id = tid + gatepos;
		int index = patterns_positions[tid + until_now];
		dev_table[thread_id].offset = offset;
		dev_table[thread_id].input[k] = dev_res[index+pos].output;
		dev_table[thread_id].m0 = 1;
		Goodsim[thread_id] = devres[good_index+index];
		//dev_table[thread_id].m1 = 0;
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

	HANDLE_ERROR( cudaSetDevice (0));
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



extern "C" void device_allocations2(int tot)
{
	size_t size = 120000000;

	//HANDLE_ERROR( cudaSetDevice (2));

    //allocations cuda table
	//printf("CUDA tot = %d\n",tot);
	HANDLE_ERROR( cudaMalloc( (void**)&dev_table2, size*sizeof(THREADFAULTYPE)));
	HANDLE_ERROR(cudaMemset(dev_table2, 0, size*sizeof(THREADFAULTYPE)));
	//allocations for result table
	HANDLE_ERROR( cudaMalloc( (void**)&dev_res2, size*sizeof(int)));
	HANDLE_ERROR( cudaMalloc( (void**)&patterns_positions, tot*sizeof(int)));
	HANDLE_ERROR( cudaMemcpy(patterns_positions, patterns_posit, tot * sizeof(int) , cudaMemcpyHostToDevice));
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
				//allagh = until_now??
				//cg->flevel_pos[i] = real_faults;
				cg->flevel_pos[i] = fault_list[i].until_now;

				if (cg->fn != PI) {
					for (k = 0; k<cg->ninput; k++) {
						hg = cg->inlis[k];
						//apo pou tha ksekinhsei na diavazei (Logis sim pinaka)
						array = hg->index * patterns;
						//pou tha grapsei
						//arr = real_faults*patterns;
						arr = fault_list[i].until_now;
						//printf("%s me index %d  ",hg->symbol->symbol,hg->index);

						fill_fault_struct_kernel_notPI<<<blocks,threads>>>(dev_table2, dev_res, cg->offset, fault_list[i].tot_patterns, arr, inj_bit0, inj_bit1, array, k,patterns_positions);

					}
				}

				else {
					//Einai PI
					//apo pou tha diavsei
					gatepos = cg->level_pos*patterns;
					//printf("%s %d ",cg->symbol->symbol,cg->level_pos);
					//pou tha grapsei
					//arr = real_faults*patterns;
					arr = fault_list[i].until_now;

					fill_fault_struct_kernel_PI<<<blocks,threads>>>(dev_table2, cuda_vecs, PI, fault_list[i].tot_patterns, arr, inj_bit0, inj_bit1, gatepos,patterns_positions);
			   }

			}

			else {
				fault_list[i].end = 2;
			}//end of else

		}//end for faults

		//Call fault injection

		Cuda_index = 0;
		//length = real_faults*patterns;
		length = tot_patterns;
		printf("lenth in first level %d\n",length);
		threads = 512;
		blocks = ( length + (threads-1))/threads;
		fault_injection_kernel<<<blocks,threads>>>(dev_table2, dev_res2, length, Cuda_index);
		Cuda_index = length;
}


extern "C" int fault_init_any_level(){
	int i, k;
	GATEPTR cg, hg;
	int  array, arr;
	int threads, blocks, length;
	int counter = -1;
	int prev_tot_patterns;

	prev_tot_patterns = tot_patterns;

	for (i = 0; i<total_faults; i++){
		if (fault_list[i].end != 1) {
			if(fault_list[i].TFO_stack.list[fault_list[i].TFO_stack.last]->outlis[0]->fn == PO){
				fault_list[i].end = 1;
			}
			//not PO yet
			else{
				while (fault_list[i].affected_gates > 0){
					fault_list[i].affected_gates--;
					cg = fault_list[i].TFO_stack.list[(fault_list[i].TFO_stack.last)--];
					real_faults++;
					counter++;

					//allagh = tot_patterns;??
					//cg->flevel_pos[i] = real_faults;
					cg->flevel_pos[i] = tot_patterns;

					for (k = 0; k<cg->ninput; k++){
						hg = cg->inlis[k];

						//den einai sto path ara diavase apo to non fault table
						if (hg->TFO_list[i] != 1){
							//from where it reads
							array = hg->index*patterns;
							//to where it will write
							//arr = tot_patterns kai sto telos tou kernel tot_pattern = tot_pattern + falt_list.tot;
							//mallon tha auksanetai exw apo thn if auth kai tha einai kai gia tis 2 periptwseis

							//arr = real_faults*patterns;
							arr = tot_patterns;

							//CALL KERNEL
							threads = 256;
							blocks = ( fault_list[i].tot_patterns + (threads-1))/threads;
							fill_fault_struct_kernel_Paths<<<blocks,threads>>>(dev_table2, dev_res, cg->offset,fault_list[i].tot_patterns,array,arr,k,patterns_positions,fault_list[i].until_now);

						}//end of if path
						else{
							//from where it reads
							//!!!!!idea na xrhsimopoihsoume th metablhth flevel pos gia na mas deixnei th thesh tou pinka
							//array = hg->flevel_pos[i];

							//array = hg->flevel_pos[i]*patterns;
							array = hg->flevel_pos[i];

							//to where it will write
							//!!!!allagh opws eipame

							//arr = real_faults*patterns;
							arr = tot_patterns;

							//CALL KERNEL
							threads = 256;
							blocks = ( fault_list[i].tot_patterns + (threads-1))/threads;
							fill_fault_struct_kernel_Paths<<<blocks,threads>>>(dev_table2, dev_res2, cg->offset,fault_list[i].tot_patterns,array,arr,k,patterns_positions,fault_list[i].until_now);

						}//end of else path

					}//end of inputs

					//mallon edw paei h auxhsh tou tot_patterns!!!!!!!!!
					tot_patterns = tot_patterns + fault_list[i].tot_patterns;

				}//end of while

			}//end of else

		}//end of fault_list.end != 1
	}//end of total faults

	//length = counter*patterns;
	length = tot_patterns - prev_tot_patterns;
	threads = 512;
	blocks = ( length + (threads-1))/threads;
	fault_injection_kernel<<<blocks,threads>>>(dev_table2, dev_res2, length, Cuda_index);
	Cuda_index = Cuda_index + length;
	printf("lenth until now %d\n",Cuda_index);

	return length;
}


extern "C" void device_allocations3(int tot)
{
	HANDLE_ERROR( cudaFree(dev_table2));
	HANDLE_ERROR( cudaFree(cuda_vecs));
	HANDLE_ERROR( cudaMalloc( (void**)&dev_table3, (tot)*sizeof(THREADFAULTYPE)));
	HANDLE_ERROR( cudaMalloc( (void**)&Goodsim, (tot)*sizeof(int)));
	HANDLE_ERROR( cudaMalloc( (void**)&Detection_table, (tot)*sizeof(int)));
	HANDLE_ERROR(cudaMemset(dev_table3, 0, (tot)*sizeof(THREADFAULTYPE)));
}


//prepei na eisagw sto fill kernels kai tis times tou goodsim
extern "C" void prepare_detection_table()
{
	int i, k;
	GATEPTR cg, hg;
	int counter = 0;
	int array, arr;
	int threads,blocks;
	int good_index;

	printf("i am in detect\n");

	for (i = 0; i<total_faults; i++){
		if ((fault_list[i].end == 1) ||(fault_list[i].TFO_stack.list[fault_list[i].TFO_stack.last]->outlis[0]->fn == PO)) {
			//printf("Arxiko sfalma %s\n",fault_list[i].gate->symbol->symbol);
			//printf("Exoume %d pules mesa sto %d sfalma\n",fault_list[i].TFO_stack.last,i);
			while(fault_list[i].TFO_stack.last>=0){

				//an exei mono ena sfalma tote prpeei na ginei injection
				cg = fault_list[i].TFO_stack.list[(fault_list[i].TFO_stack.last)--];

				//apo pou tha diabasei gia to kalo kuklwma gia to detection
				good_index = cg->index*patterns;

				//printf("lista %s\n",cg->symbol->symbol);
				//offset = find_offset(cg);

				//pare ta apotelesmata kai valta ston pinaka detect
				for (k = 0; k<cg->ninput; k++) {
					hg = cg->inlis[k];
					//printf("read inputs %s\n",hg->symbol->symbol);
					if(hg->TFO_list[i] != 1){

						//h thesh ston apothkeumeno pinaka
						array = hg->index*patterns;
						//h thesh ston pinaka pou ftiaxnoume prepei na auxhthei meta
						arr = counter;
						threads = 256;
						blocks = ( fault_list[i].tot_patterns + (threads-1))/threads;
						fill_detetection_struct<<<threads,blocks>>>(dev_table3, dev_res, cg->offset,fault_list[i].tot_patterns,array,arr,k,patterns_positions,fault_list[i].until_now,good_index,Goodsim,dev_res);
					}
					else{
						//h thesh ston apothkeumeno pinaka
						array = hg->flevel_pos[i];
						//h thesh ston pinaka pou ftiaxnoume
						arr = counter;
						threads = 256;
						blocks = ( fault_list[i].tot_patterns + (threads-1))/threads;
						fill_detetection_struct<<<threads,blocks>>>(dev_table3, dev_res2, cg->offset,fault_list[i].tot_patterns,array,arr,k,patterns_positions,fault_list[i].until_now,good_index,Goodsim,dev_res);
					}
				}//end for inputs
				counter = counter + fault_list[i].tot_patterns;
			}//end of while

		}//if checking
		else printf("something went wrong!\n");
	}//end of faults

	//CALL fault detection kernel
	printf("Synoliko %d",counter);
	fault_detection_kernel<<<threads,blocks>>>(dev_table3,Detection_table,Goodsim, counter);
}







extern "C" void device_deallocations3()
{
    // Free device global memory
	HANDLE_ERROR( cudaFree(dev_table3));
	HANDLE_ERROR( cudaFree(Goodsim));
    HANDLE_ERROR( cudaFree(dev_LUT));
    HANDLE_ERROR( cudaFree(dev_res2));
    HANDLE_ERROR( cudaFree(dev_res));
    //HANDLE_ERROR( cudaDeviceReset());
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
