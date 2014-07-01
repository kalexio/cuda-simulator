#include "define.h"
#include "structs.h"

THREADFAULTPTR fault_tables;

allocate_cuda_faultables()
{
	int i;

	fault_tables = xmalloc(no_po_faults*sizeof(THREADFAULTYPE));


}
