################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
C_SRCS += \
../src/common.c \
../src/fault_sim.c \
../src/fsim.c \
../src/hashes.c \
../src/logic_sim.c \
../src/main.c \
../src/read_circuit.c \
../src/read_vectors.c \
../src/structures.c 

CU_SRCS += \
../src/my_cuda.cu 

CU_DEPS += \
./src/my_cuda.d 

OBJS += \
./src/common.o \
./src/fault_sim.o \
./src/fsim.o \
./src/hashes.o \
./src/logic_sim.o \
./src/main.o \
./src/my_cuda.o \
./src/read_circuit.o \
./src/read_vectors.o \
./src/structures.o 

C_DEPS += \
./src/common.d \
./src/fault_sim.d \
./src/fsim.d \
./src/hashes.d \
./src/logic_sim.d \
./src/main.d \
./src/read_circuit.d \
./src/read_vectors.d \
./src/structures.d 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.c
	@echo 'Building file: $<'
	@echo 'Invoking: NVCC Compiler'
	/usr/local/cuda-5.5/bin/nvcc -G -g -O0 -gencode arch=compute_10,code=sm_10 -gencode arch=compute_13,code=sm_13 -odir "src" -M -o "$(@:%.o=%.d)" "$<"
	/usr/local/cuda-5.5/bin/nvcc -G -g -O0 --compile  -x c -o  "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '

src/%.o: ../src/%.cu
	@echo 'Building file: $<'
	@echo 'Invoking: NVCC Compiler'
	/usr/local/cuda-5.5/bin/nvcc -G -g -O0 -gencode arch=compute_10,code=sm_10 -gencode arch=compute_13,code=sm_13 -odir "src" -M -o "$(@:%.o=%.d)" "$<"
	/usr/local/cuda-5.5/bin/nvcc --compile -G -O0 -g -gencode arch=compute_10,code=compute_10 -gencode arch=compute_10,code=sm_10 -gencode arch=compute_13,code=sm_13  -x cu -o  "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


