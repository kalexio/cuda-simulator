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

void dummy_gpu(int);
void dummy_gpu2(int);
void dummy_gpu3();
void device_allocations();
void device_allocations2();
void device_allocations3();
void dealloc();
void alloc();
void device_deallocations();
void device_deallocations2();
void device_deallocations3();


#endif
