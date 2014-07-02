#include "define.h"
#include "structs.h"

THREADFAULTPTR fault_tables;

void allocate_cuda_faultables()
{
	fault_tables = xmalloc(no_po_faults*patterns*sizeof(THREADFAULTYPE));
}

void init_faultable(THREADFAULTPTR table)
{
	int i, j, k, offset;
	GATEPTR cg, hg;
	int inj_bit0 = 1;
	int inj_bit1 = 0;
	int epipedo, gatepos, array, arr, pos;

	//ola ta sfalamata ektos twn PO (apo fault_list)
	for (i = 0; i<total_faults; i++){
		//vriskw to offset ths pulhs kai ta inj bits
		cg = fault_list[i].gate;
		offset = find_offset(cg);
		//<-----------------------------xreiazomai if gia na dw an
		//einai PO kai na to steilw sto detection kernel
		//h an einai PI gia na diavasw apla thn eisodo kai oxi prohgoumenes pules
		if (fault_list[i].SA == 0) {inj_bit0 = 0; inj_bit1 = 0;}
		else inj_bit1 = 1;
		//ola ta vectors

		//koita tis inlist kai pare th thesh twn pulwn apo tis opoies tha diavasoume
		//to result tous gia sygkekrimeno pattern
		for (k = 0; k<cg->ninput; k++) {
			hg = cg->inlis[k];
			//epidedo pou vrisketai h pulh kai se shmeio sto epipedo
			epipedo = hg->level;
			gatepos = hg->level_pos;

			array=gatepos*patterns;
			arr = i*patterns;

			for (j = 0; j<patterns; j++){
				pos = arr + j;
				table[pos].offset = offset;
				table[pos].m0 = inj_bit0;
				table[pos].m1 = inj_bit1;
				table[pos].input[k] = result_tables[epipedo][array+j].output;
			}
		}
	}

}


