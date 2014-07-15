#include "define.h"
#include "structs.h"

THREADFAULTPTR *fault_tables;
RESULTPTR *fault_result_tables;
THREADFAULTPTR detect_tables;
//STACKPTR *TFO_list;
int next_level_length = 0;
//deixnei se poio sfalma eimaste apo ta anixneumena
int detect_index = 0;



void allocate_cuda_faultables()
{
	//desmeuoyme mnhmh gia to prwto epipedo osa einai ta faults without the PO faults
	fault_tables = xmalloc((maxlevel-2)*sizeof(THREADFAULTPTR));
	fault_result_tables = xmalloc((maxlevel-2)*sizeof(RESULTPTR));
	fault_tables[0] = xmalloc(no_po_faults*patterns*sizeof(THREADFAULTYPE));
	fault_result_tables[0] = xmalloc(no_po_faults*patterns*sizeof(RESULTYPE));
	detect_tables = xmalloc(10000*sizeof(THREADFAULTYPE));
	//TFO //genikos deikths se lista gia ola ta sfalamata
	//printf("the lenght is %d\n",no_po_faults*patterns);
}



//allocate an array for the TFO gates
void allocate_TFO_lists()
{
	int i;
	GATEPTR cg;

	for (i = 0; i<nog; i++) {
		cg = net[i];
		cg->TFO_list = xmalloc(total_faults*sizeof(int));
	}
}



//arxikopoiei to prwto epipedo tou pinaka faults
void init_faultable(THREADFAULTPTR table,THREADFAULTPTR dtable)
{
	int i, j, k, offset;
	GATEPTR cg, hg;
	int inj_bit0 = 1;
	int inj_bit1 = 0;
	int epipedo, gatepos, array, arr, pos;
	int real_faults = -1;  // <-----------------------


	printf("i am in faultable\n");

	//ola ta sfalamata ektos twn PO (apo fault_list)
	for (i = 0; i<total_faults; i++){
		//vriskw to offset ths pulhs kai ta injection bits eite einai PI PO etc
		cg = fault_list[i].gate;
		offset = find_offset(cg);
		if (fault_list[i].SA == 0) {inj_bit0 = 0; inj_bit1 = 0;}
		else inj_bit1 = 1;
		printf("%s\n",cg->symbol->symbol);
		if ( cg->outlis[0]->fn != PO ) { //den einai PO
			real_faults++;
			//printf("I am not a PO real fault=%d\n",real_faults);
			fault_list[i].affected_gates = cg->noutput;
			next_level_length = next_level_length + fault_list[i].affected_gates;
			//koita tis inlist kai pare th thesh twn pulwn apo tis opoies tha diavasoume
			//to result tous gia sygkekrimeno pattern
			//an einai PI diavase apla to vectors
			if (cg->fn != PI) {//den einai PI opote diavazoume apo prohgoymenes pules
				//printf("i am not a PI\n");
				for (k = 0; k<cg->ninput; k++) {
					hg = cg->inlis[k];
					//epidedo pou vrisketai h pulh kai se shmeio sto epipedo
					epipedo = hg->level;
					gatepos = hg->level_pos;

					//h thesh ston apothkeumeno pinaka
					array=gatepos*patterns;
					//h thesh ston pinaka pou ftiaxnoume
					arr = real_faults*patterns;

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
				//fault_list[i].affected_gates = cg->noutput;
				//next_level_length = next_level_length + fault_list[i].affected_gates;
				//poia pulh sth seira einai
				gatepos = cg->level_pos;
				arr = real_faults*patterns;
				//printf("I am a PI read the input vector\n");
				for (j = 0; j<patterns; j++){
					pos = arr + j;
					table[pos].offset = offset;
					//j deixnei grammes osa ta patterns , i diexnei sthlh dhladh poia pulh
					table[pos].input[0] = test_sets[j][gatepos];
					//printf("%d",test_sets[j][gatepos]);
					table[pos].input[1] = 0;
					table[pos].input[2] = 0;
					table[pos].input[3] = 0;
					table[pos].m0 = inj_bit0;
					table[pos].m1 = inj_bit1;
				}
		   }
		}//end if not PO
		else {
			//end this fault
			fault_list[i].end = 1;
			//deixnei th thesh tou sfalmatos ston teliko pinaka
			fault_list[i].fault_pos_indetect = detect_index;
			printf("I am a PO send me to the detection\n");
			//MAKE INSERT FAULT FUNCTION <---------------------------
			//etoimase tis PO gia to detection kernel
			//ftiakse kai to GoodSim <------------------------------------------------------------
			for (k = 0; k<cg->ninput; k++) {
				hg = cg->inlis[k];
				//epidedo pou vrisketai h pulh kai se shmeio sto epipedo
				epipedo = hg->level;
				gatepos = hg->level_pos;

				//h thesh ston apothkeumeno pinaka
				array=gatepos*patterns;
				//h thesh ston pinaka pou ftiaxnoume
				arr = detect_index*patterns;

				for (j = 0; j<patterns; j++){
					pos = arr + j;
					dtable[pos].offset = offset;
					dtable[pos].input[k] = result_tables[epipedo][array+j].output;
					dtable[pos].m0 = inj_bit0;
					dtable[pos].m1 = inj_bit1;
				}//end for patterns
			}//end for inputs
			detect_index++;
		}//end of else
	}//end for faults
	//printf("the lentgh is %d\n",pos+1);
	printf("next level length is %d\n",next_level_length);
}



void compute_TFO()
{
	int i, j;
	GATEPTR cg, ng;

	for (i = 0; i<total_faults; i++){
		if (fault_list[i].end != 1) {
			//ypologise ta TFO list
			clear(stack3);
			cg = fault_list[i].gate;
			//printf("H pylh gia thn opoia tha vroyme lista einai h %s me out %d\n",cg->symbol->symbol,cg->noutput);
			for (j = 0; j<cg->noutput; j++) {
				ng = cg->outlis[j];
				if (ng->fn != PO) push(stack3,ng);
			}

			while (!is_empty(stack3)) {
				cg = pop(stack3);
				//printf("exei TFO tis %s\n",cg->symbol->symbol);
				cg->TFO_list[i] = 1;
				for (j = 0; j<cg->noutput; j++) {
					ng = cg->outlis[j];
					if ((ng->fn != PO) && (ng->TFO_list[i] != 1)) push(stack3,ng);
				}
			}

		}
	}
}



//vazei tis pules pou prepei na eksomoiwthoun gia kathe sfalma
void init_anylevel_faultable(int lev, int prev_len)
{





}
