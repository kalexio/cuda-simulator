#include "define.h"
#include "structs.h"

FAULTPTR fault_list;
int total_faults;
int no_po_faults;


void create_fault_list ()
{
	int i;
	//int j = 0;
	int j = 200;
	
	//total_faults = 2*(nog-levels[maxlevel-1]);
	total_faults = 450;
	no_po_faults = 0;
	printf("total fault =%d\n",total_faults);
	printf("I have %d number of PI and %d number of gates\n",nopi,nog);
	
	fault_list = (FAULTYPE *)xmalloc(total_faults*sizeof(FAULTYPE));
	//printf("%d",event_list[0].last+1);
	
	for (i= 0; i<total_faults; i+=2) {
		fault_list[i].gate = net[j];
		fault_list[i].affected_gates = 0;
		fault_list[i].end = 0;
		//vriskei to sunolo twn faults_without po
		if ( net[j]->outlis[0]->fn != PO ) no_po_faults++;
		fault_list[i].SA = 0;
		fault_list[i+1].gate = net[j];
		fault_list[i+1].affected_gates = 0;
		fault_list[i+1].end = 0;
		if ( net[j]->outlis[0]->fn != PO ) no_po_faults++;
		fault_list[i+1].SA = 1;
		j++;		
	}
	
	printf("total no output fault =%d\n",no_po_faults);
}



void print_fault_list ()
{
	int i;
	for (i= 0; i<total_faults; i++) 
		printf("%s / %d\n",fault_list[i].gate->symbol->symbol,fault_list[i].SA);
}


