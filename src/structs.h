/***********************************************************************
 *     Contains the structs that are used
 * ********************************************************************/
#ifndef STRUCTS_H 
#define STRUCTS_H

typedef struct HASH {
    int key;
    struct GATE *pnode;
    struct HASH *next;
    char *symbol;
} HASHTYPE, *HASHPTR;

typedef struct GATE {
	int level_pos;
	int index;
    int fn;
    short level;
    int changed;
    short ninput;
    struct THREAD *threadData;
    struct THREADFAULT *faultData;
    struct RESULT *result;
    struct GATE **inlis;
    short noutput;
    struct GATE **outlis;
    struct HASH *symbol;
    struct GATE *next;
} GATETYPE, *GATEPTR;

typedef struct STACK {			
	int last;
	struct GATE **list;
} STACKTYPE, *STACKPTR;

typedef struct THREAD {
	//int count;   //helps for the incoming values from multiple fanins - we dont need it for cuda
	int offset;
	int input[4];
} THREADTYPE, *THREADPTR;

typedef struct THREADFAULT {
	//int count;   helps for the incoming values from multiple fanins - we dont need it for cuda
	int offset;
	int input[4];
	int m0;
	int m1;
} THREADFAULTYPE, *THREADFAULTPTR;


typedef struct THREADETECT {
	//int count;   helps for the incoming values from multiple fanins - we dont need it for cuda
	int offset;
	int input[4];
	int Good_Circuit_threadID;
} THREADETECTYPE, *THREADETECTPTR;

typedef struct RESULT {
	int output;
} RESULTYPE, *RESULTPTR;

typedef struct FAULT {
	struct GATE *gate;
	int SA;
	int affected_gates;
	int end;
} FAULTYPE, *FAULTPTR;

#endif
