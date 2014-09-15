
#include "define.h"
#include "structs.h"

THREADFAULTPTR *fault_tables;
RESULTPTR *fault_result_tables;
THREADFAULTPTR detect_tables;
RESULTPTR GoodSim;
RESULTPTR Final;
int *patterns_posit;
int tot_patterns = 0;;
int detect_index = -1;


//allocate an array for the TFO gates
void allocate_TFO_lists()
{
	int i;
	GATEPTR cg;

	for (i = 0; i<nog; i++) {
		cg = net[i];
		cg->TFO_list = xmalloc(total_faults*sizeof(int));
		memset(cg->TFO_list, 0, total_faults*sizeof(int));
		cg->fault_level = xmalloc(total_faults*sizeof(int));
		memset(cg->fault_level, 0, total_faults*sizeof(int));
		cg->flevel_pos = xmalloc(total_faults*sizeof(int));
		memset(cg->flevel_pos, 0, total_faults*sizeof(int));
	}
}


//tot_patterns = posa sunolika sfalmata tha exomoiwthoun
//faultlist.tot_patterns = posa sfalmata gia to sygkekrimeno sfalma
//until_now  = se poia thesh tou pinaka ksekinaei to sygkekrimeno sfalma
void count_fault_patterns()
{
	int i,j,index,value,counter;
	GATEPTR cg,hg;

	for (i = 0; i<total_faults; i++){
		value = fault_list[i].SA;
		fault_list[i].tot_patterns = 0;
		index = fault_list[i].gate->index * patterns;
		fault_list[i].until_now = tot_patterns;
		for (j = 0; j<patterns; j++){
			if(value != result_tables[index+j].output) fault_list[i].tot_patterns++;
		}
		tot_patterns = tot_patterns + fault_list[i].tot_patterns;
	}
	patterns_posit = xmalloc(tot_patterns*sizeof(int));
	printf("total patterns to be simulated %d\n",tot_patterns);

	counter = -1;
	for (i = 0; i<total_faults; i++){
		value = fault_list[i].SA;
		index = fault_list[i].gate->index * patterns;
		for (j = 0; j<patterns; j++){
			if(value != result_tables[index+j].output){
				counter++;
				//fault_list[i].patterns_posit[counter] = j;
				patterns_posit[counter] = j;
			}
		}
	}
	//printf("counter = %d anti gia %d\n",counter,patterns*total_faults);

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
			//printf("TFO list for %s\n",cg->symbol->symbol);
			//vriskoume ta pules pou ephreazei to sfalma
			for (j = 0; j<cg->noutput; j++) {
				ng = cg->outlis[j];
				if (ng->fn != PO) {push(stack1,ng); push(stack2,ng);}
			}

			while (!is_empty(stack1)) {
				cg = pop(stack1);
				//printf("exei TFO tis %s\n",cg->symbol->symbol);
				cg->TFO_list[i] = 1;
				//printf("%s %d  %d\n",cg->symbol->symbol,i,cg->TFO_list[i]);
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
					if (cg->TFO_list[i] == 1) {
					    push(stack3,cg); 
					    //printf("oi pyles tou TFO me seira einai  %s\n",cg->symbol->symbol);
					}
				}
			}

			//if(stack3.last+1 == stack2.last+1) printf("mallon swsta ta ypologisame\n");

			//vgazoume tis pules apo th stoiva me anastrofh seira kai tis eisagoume sth stoivoyla toy sfalmato

			while (!is_empty(stack3)){
				cg = pop(stack3);
				push(fault_list[i].TFO_stack,cg);
			}

			//Error checking for the final stack
			//printf("Our stack contains:\n");
			//for (j = 0; j<stack2.last+1; j++) printf("%s\n",fault_list[i].TFO_stack.list[j]->symbol->symbol);
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

	//printf("i am in compute length\n");

	for (i = 0; i<total_faults; i++){
		if (fault_list[i].end != 1) {
			// vres to arxiko epipedo ths prwths epomenhs pulhs kai an den einai PO metra th
			//printf("arxiko sfalma %s\n",fault_list[i].gate->symbol->symbol);
			if (fault_list[i].TFO_stack.list[fault_list[i].TFO_stack.last]->outlis[0]->fn != PO) {
				init_level = fault_list[i].TFO_stack.list[fault_list[i].TFO_stack.last]->level;
				//printf("Prwth tou epipedou %s\n",fault_list[i].TFO_stack.list[fault_list[i].TFO_stack.last]->symbol->symbol);
				fault_list[i].affected_gates = 1;
				counter++;
				//vres tis pules ths stoivas pou exoun to idio level
				//ara ksekina to apo to telos ths stoivas -1  kai otan diaferoun stamata
				for (j = fault_list[i].TFO_stack.last-1; j>=0; j--){
					level = fault_list[i].TFO_stack.list[j]->level;
					if (level == init_level){
						fault_list[i].affected_gates++;
						//printf("idies %s\n",fault_list[i].TFO_stack.list[j]->symbol->symbol);
						counter++;
					}
					else{
					   //printf("end\n"); 
					    break;
					}
				}
			}
		}
	}

	//returns the full number of affect gates for all the faults
	return counter;
}





int compute_detected()
{
	int counter = 0;
	int i, j;
	int counter2;

	for (i = 0; i<total_faults; i++){
		counter = counter + fault_list[i].TFO_stack.last+1;
		counter2 = counter2 + ((fault_list[i].TFO_stack.last+1) * fault_list[i].tot_patterns);
		//printf("Error checking\n");
		//printf("Pulh ->%d %s\n",i,fault_list[i].gate->symbol->symbol);
		//printf("Our stack contains:\n");
		//for (j = 0; j<fault_list[i].TFO_stack.last+1; j++) printf("%s\n",fault_list[i].TFO_stack.list[j]->symbol->symbol);
	}
	printf("For detection we have %d gates in total\n",counter);
	return counter2;
}
