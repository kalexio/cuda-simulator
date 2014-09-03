#ifndef MY_DUMMY
#define MY_DUMMY

#include <cuda_runtime.h>


static void HandleError( cudaError_t err,const char *file,int line ) {
    if (err != cudaSuccess) {
        printf( "%s in %s at line %d\n", cudaGetErrorString( err ),
                file, line );
        exit( EXIT_FAILURE );
    }
}
#define HANDLE_ERROR( err ) (HandleError( err, __FILE__, __LINE__ ))


#define HANDLE_NULL( a ) {if (a == NULL) { \
                            printf( "Host memory failed in %s at line %d\n", \
                                    __FILE__, __LINE__ ); \
                            exit( EXIT_FAILURE );}}

void device_allocations();
void init_first_level();
void init_any_level();
void device_allocations2(int);
void fault_init_first_level();
int fault_init_any_level();
void device_allocations3(int tot);
void device_deallocations3();
int find_offset(GATEPTR);

#endif
