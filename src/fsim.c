#include "define.h"
#include "structs.h"

THREADFAULTPTR *fault_tables;
RESULTPTR *fault_result_tables;
THREADFAULTPTR detect_tables;
//STACKPTR *TFO_list;
//deixnei se poio sfalma eimaste apo ta anixneumena
int detect_index = -1;



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
		//memset(cg->TFO_list, 0, total_faults*sizeof(int));
		cg->fault_level = xmalloc(total_faults*sizeof(int));
		//memset(cg->fault_level, 0, total_faults*sizeof(int));
		cg->flevel_pos = xmalloc(total_faults*sizeof(int));
		//memset(cg->flevel_pos, 0, total_faults*sizeof(int));
	}
}



//arxikopoiei to prwto epipedo tou pinaka faults
void init_faultable(THREADFAULTPTR table, THREADFAULTPTR dtable)
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
			//thesh stou pinakes twn faults
			cg->fault_level[i] = 0;
			cg->flevel_pos[i] = real_faults;
			//printf("I am not a PO real fault=%d\n",real_faults);
			//fault_list[i].affected_gates = cg->noutput;
			//next_level_length = next_level_length + fault_list[i].affected_gates;
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
			detect_index++;
			fault_list[i].fault_pos_indetect = detect_index;
			//poses pules ephreazei to sfalma ston detect table
			fault_list[i].affected_gates = 1;
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
		}//end of else
	}//end for faults
	//printf("the lentgh is %d\n",pos+1);
}



void compute_TFO()
{
	int i, j, k;
	GATEPTR cg, ng;
	int big_lev = -1;

	for (i = 0; i<total_faults; i++){
		if (fault_list[i].end != 1) {
			//ypologise ta TFO list
			clear(stack1);
			clear(stack2);
			clear(stack3);
			cg = fault_list[i].gate;
			printf("H pylh gia thn opoia tha vroyme lista einai h %s me out %d\n",cg->symbol->symbol,cg->noutput);
			//vriskoume ta pules pou ephreazei to sfalma
			for (j = 0; j<cg->noutput; j++) {
				ng = cg->outlis[j];
				if (ng->fn != PO) {push(stack1,ng); push(stack2,ng);}
			}

			while (!is_empty(stack1)) {
				cg = pop(stack1);
				//printf("exei TFO tis %s\n",cg->symbol->symbol);
				cg->TFO_list[i] = 1;
				for (j = 0; j<cg->noutput; j++) {
					ng = cg->outlis[j];
					if ((ng->fn != PO) && (ng->TFO_list[i] != 1)) {push(stack1,ng); push(stack2,ng);}
				}
			}

			//desmeush mnhmh gia to stack to megethos kratietai sto stack2
			//ftiaxnoyme mia stoiboula sto struct tou kathe sfalmatos
			fault_list[i].TFO_stack.list = (GATEPTR *)xmalloc((stack2.last+1)*sizeof(GATEPTR));
			clear(fault_list[i].TFO_stack);
			//sto stack3 vazoume me seira tis pules pou ephreazei to sfalma
			//loop apo to epipedo tou sfalmatos mexri thn eksodo
			for (j = fault_list[i].gate->level+1; j<maxlevel-1; j++){
				//loop gia oles tis pules tou epipedou opou koitame an exoun to bit tou TFO
				for (k = 0; k<=event_list[j].last; k++){
					cg = event_list[j].list[k];
					if (cg->TFO_list[i] == 1) {push(stack3,cg); printf("oi pyles tou TFO me seira einai  %s\n",cg->symbol->symbol);}
				}
			}

			if(stack3.last+1 == stack2.last+1) printf("mallon swsta ta ypologisame\n");

			//vgazoume tis pules apo th stoiva me anastrofh seira kai tis eisagoume sth stoivoyla toy sfalmato
			//pop me  is_emptyy??????????????????????????????????????????????????????


			while (!is_empty(stack3)){
				cg = pop(stack3);
				push(fault_list[i].TFO_stack,cg);
			}

			/*for (j = stack3.last+1; j> 0; j--) {
				cg = pop(stack3);
				push(fault_list[i].TFO_stack,cg);
			}*/

			printf("Our stack contains:\n");
			for (j = 0; j<stack2.last+1; j++) printf("%s\n",fault_list[i].TFO_stack.list[j]->symbol->symbol);
		}
	}
}


//kaleitai ana epipedo alla de thelei orismata giati leotpurgei me ta stack twn sfalmatwn
int compute_length()
{
	int i, j;
	int counter = 0;
	int level, init_level;
	int flag = 1;

	for (i = 0; i<total_faults; i++){
		if (fault_list[i].end != 1) {
			// vres to arxiko epipedo ths prwths epomenhs pulhs kai an den einai PO metra th
			if (fault_list[i].TFO_stack.list[fault_list[i].TFO_stack.last]->outlis[0]->fn != PO) {
				init_level = fault_list[i].TFO_stack.list[fault_list[i].TFO_stack.last]->level;
				//printf("gia epipedo koitame thn %s\n",fault_list[i].TFO_stack.list[fault_list[i].TFO_stack.last]->symbol->symbol);
				fault_list[i].affected_gates = 1;
				counter++;
				//vres tis pules ths stoivas pou exoun to idio level
				//ara ksekina to apo to telos ths stoivas -1  kai otan diaferoun stamata
				for (j = fault_list[i].TFO_stack.last-1; j>=0; j--){
					level = fault_list[i].TFO_stack.list[j]->level;
					if (level == init_level){
						fault_list[i].affected_gates++;
						//printf("idies %d\n",fault_list[i].affected_gates);
						counter++;
					}
					else{/*printf("end\n");*/ break;}
				}
			}
		}
	}

	//returns the full number of affect gates for all the faults
	return counter;
}


//vazei tis pules pou prepei na eksomoiwthoun gia kathe sfalma
//dexetai ton arithmo pulwn gia desmeush mnhmhs tous pinakes pou tha valei tis pyles kai
//ton arithmo tou loop
void init_anylevel_faultable(int prev_len, int loop, THREADFAULTPTR table, THREADFAULTPTR dtable)
{
	int i, k, j;
	GATEPTR cg, hg;
	int epipedo, gatepos, array, arr, pos, offset;

	fault_tables[loop] = xmalloc(prev_len*patterns*sizeof(THREADFAULTYPE));
	fault_result_tables[loop] = xmalloc(prev_len*patterns*sizeof(RESULTYPE));

	for (i = 0; i<total_faults; i++){
		if (fault_list[i].end != 1) {
			//PO
			if(fault_list[i].TFO_stack.list[fault_list[i].TFO_stack.last]->outlis[0]->fn == PO){
				fault_list[i].end = 1;
				detect_index++;
				fault_list[i].fault_pos_indetect = detect_index;
				fault_list[i].affected_gates = 0;
				while(!is_empty(fault_list[i].TFO_stack)){
					cg = pop(fault_list[i].TFO_stack);
					offset = find_offset(cg);

					//pare ta apotelesmata kai valta ston pinaka detect

					for (k = 0; k<cg->ninput; k++) {
						hg = cg->inlis[k];
						if(hg->TFO_list[i] != 1){
							//epidedo pou vrisketai h pulh kai se shmeio sto epipedo
							epipedo = hg->level;
							gatepos = hg->level_pos;

							//h thesh ston apothkeumeno pinaka
							array=gatepos*patterns;
							//h thesh ston pinaka pou ftiaxnoume
							arr = (detect_index+fault_list[i].affected_gates)*patterns;

							for (j = 0; j<patterns; j++){
								pos = arr + j;
								dtable[pos].offset = offset;
								dtable[pos].input[k] = result_tables[epipedo][array+j].output;
								//mallon prepei na bgoun
								dtable[pos].m0 = 1;
								dtable[pos].m1 = 0;
							}//end for patterns
						}
						else{
							epipedo = hg->fault_level[i];
							gatepos = hg->flevel_pos[i];

							//h thesh ston apothkeumeno pinaka
							array=gatepos*patterns;
							//h thesh ston pinaka pou ftiaxnoume
							arr = (detect_index+fault_list[i].affected_gates)*patterns;

							for (j = 0; j<patterns; j++){
								pos = arr + j;
								dtable[pos].offset = offset;
								dtable[pos].input[k] = result_tables[epipedo][array+j].output;
								//mallon prepei na bgoun
								dtable[pos].m0 = 1;
								dtable[pos].m1 = 0;
							}//end for patterns

						}
					}//end for inputs

					fault_list[i].affected_gates++;
				}
			}
			//not PO yet
			else{

			}


		}
	}



}
