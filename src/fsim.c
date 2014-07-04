#include "define.h"
#include "structs.h"

THREADFAULTPTR fault_tables;
int next_level_length;

void allocate_cuda_faultables()
{
	fault_tables = xmalloc(no_po_faults*patterns*sizeof(THREADFAULTYPE));
	//printf("the lenght is %d\n",no_po_faults*patterns);
}

//arxikopoiei to prwto epipedo tou pinaka faults
void init_faultable(THREADFAULTPTR table)
{
	int i, j, k, offset;
	GATEPTR cg, hg;
	int inj_bit0 = 1;
	int inj_bit1 = 0;
	int epipedo, gatepos, array, arr, pos;


	printf("i am in faultable\n");

	//ola ta sfalamata ektos twn PO (apo fault_list)
	for (i = 0; i<total_faults; i++){
		//vriskw to offset ths pulhs kai ta injection bits eite einai PI PO etc
		cg = fault_list[i].gate;
		offset = find_offset(cg);
		if (fault_list[i].SA == 0) {inj_bit0 = 0; inj_bit1 = 0;}
		else inj_bit1 = 1;
		printf("%s",cg->symbol->symbol);
		if ( cg->outlis[0]->fn != PO ) { //den einai PO
			next_level_length = next_level_length + cg->noutput;
			//koita tis inlist kai pare th thesh twn pulwn apo tis opoies tha diavasoume
			//to result tous gia sygkekrimeno pattern
			//an einai PI diavase apla to vectors
			if (cg->fn != PI) {//den einai PI opote diavazoume apo prohgoymenes pules
				for (k = 0; k<cg->ninput; k++) {
					hg = cg->inlis[k];
					//epidedo pou vrisketai h pulh kai se shmeio sto epipedo
					epipedo = hg->level;
					gatepos = hg->level_pos;

					//h thesh ston apothkeumeno pinaka
					array=gatepos*patterns;
					//h thesh ston pinaka pou ftiaxnoume
					arr = i*patterns;

					for (j = 0; j<patterns; j++){
						pos = arr + j;
						table[pos].offset = offset;
						table[pos].m0 = inj_bit0;
						table[pos].m1 = inj_bit1;
						table[pos].input[k] = result_tables[epipedo][array+j].output;
					}//end for patterns
				}//end for inputs
			}//end of not PI
			else {
				//poia pulh sth seira einia
				gatepos = cg->level_pos;
				arr = i*patterns;
				printf("I am a PI read the input vector\n");
				for (j = 0; j<patterns; j++){
					pos = arr + j;
					table[pos].offset = offset;
					table[pos].m0 = inj_bit0;
					table[pos].m1 = inj_bit1;
					//j deixnei grammes osa ta patterns , i diexnei sthlh dhladh poia pulh
					table[pos].input[0] = test_sets[j][gatepos];
					//printf("%d",test_sets[j][gatepos]);
					table[pos].input[1] = 0;
					table[pos].input[2] = 0;
					table[pos].input[3] = 0;
				}
		   }
		}//end if not PO
		else {
			printf("I am a PO send me to the detection\n");
			//etoimase tis PO gia to detection kernel
		}
	}//end for faults
	//printf("the lentgh is %d\n",pos+1);
	printf("next level length is %d\n",next_level_length);
}


