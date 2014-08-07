#include "define.h"
#include "structs.h"

#define is_delimiter(c) (c == ':')
#define is_comment(c) (c=='#')

char **test_set;
int **test_sets;
int *cuda_vectors;
int patterns;
int maxgates;
int total_gates = 0;
THREADTYPE **cuda_tables;
THREADFAULTYPE **cuda_table;
RESULTYPE *result_tables;

int read_vectors (FILE *vectors_fd,const char* vectors_name) 
{
	register char c;
	int valid = FALSE;
	int i, j;
    char symbol[levels[0]];
    patterns = 0;
    int counter= 0;;


    /*******************************************************************
     *  Find the total number of patterns and allocate space for them
     ******************************************************************/

    /* Finds the number of the patterns */
    while ((c = getvector (vectors_fd, symbol)) != EOF) {
		//printf("len %d\n",strlen(symbol));
		//printf("symbol = %s\n",symbol);
		patterns++;
	}

    printf("Number of patterns %d\n",patterns);

	/* Close the vectors file for opening it again*/
    fclose(vectors_fd);
    
	/* Allocate a table for preserving the test patterns */
    test_set = (char **)xmalloc(patterns*sizeof(char *));
    test_sets = (int **)xmalloc(patterns*sizeof(int *));
    cuda_vectors = xmalloc( (patterns*levels[0]) * sizeof(int) );
    for ( i = 0; i < patterns; i++) {
		test_sets[i] = xmalloc(levels[0]*sizeof(int));
	}
	
    
    /***********************************************************************
     * 			 Read as int the input vectors
     * ********************************************************************/


    /* Open it again and read from the start */
    vectors_fd = fopen (vectors_name, "r");
	if (vectors_fd == NULL)
		system_error ("fopen");
		
	patterns = 0;
	i = 0;
	/* Read the patterns into the array as ints*/
	while((c=getc(vectors_fd)) != EOF) { //printf("%c\n",c);
		switch(c) {
			case '0': if(valid) { test_sets[patterns][i++] = ZERO; } 
				break;
			case '1': if(valid) { test_sets[patterns][i++] = ONE; } 
				break;
			case ':': valid = TRUE; 
				break;
			case '*': while((c=getc(vectors_fd))!='\n') if(c == EOF) break; 
				break;
			case '\n': valid = FALSE; patterns++; i = 0;
				break;
		}
	}  

	/* Close the vectors file */
	fclose (vectors_fd);  


	//fill the cuda_vectors array
	for (i = 0; i < levels[0]; i++) {
		for ( j = 0; j < patterns; j++) {
			cuda_vectors[counter] =  test_sets[j][i];
			counter++;
		}
	}

	/* Test the int reading vectors
	for (i = 0; i < levels[0]; i++) {
		for ( j = 0; j < patterns; j++) printf("%d",test_sets[j][i]);
		printf("\n");
	} */
	
	/*Test the cuda vector
	for (i = 0; i<patterns*levels[0]; i++) printf("%d",cuda_vectors[i]); */
	
	cuda_table = xmalloc (  patterns*nog*sizeof(THREADFAULTYPE));
	result_tables = xmalloc (  patterns*nog*sizeof(RESULTYPE));
	//allocate_and_init ();
	//allocate_cudatables ();
	//init_first_level (cuda_tables[0]);
 
	return 0;
	
}


void Compute_gates(){
	int i;

	for (i = 0; i< maxlevel-1; i++){
		total_gates = total_gates + levels[i];
	}

}















/*
/////////////////////////////CUDA-area//////////////////////////////////
void allocate_cudatables () 
{
	int i;
	maxgates = 0;
	
	//vale memset opwsdhpote <----------------------------------------------

	cuda_tables = xmalloc(maxlevel*sizeof(THREADPTR));
	result_tables = xmalloc(maxlevel*sizeof(RESULTPTR));
	
	for (i = 0; i < maxlevel; i++) {
		if (levels[i] > maxgates) maxgates = levels[i];
		cuda_tables[i] = xmalloc(patterns*levels[i]*sizeof(THREADTYPE));
		result_tables[i] = xmalloc(patterns*levels[i]*sizeof(RESULTYPE));
	}
	printf("End of allocatuion\n");
	
}



void init_first_level (THREADPTR table)
{
	int i, j;
	register int pos;
	
	//printf("Gates fn  data\n");
	for (i = 0; i<levels[0]; i++)
	{
		//printf("%s  %d ",net[i]->symbol->symbol,net[i]->fn);
		for (j = 0; j<patterns; j++) {
			pos = i*patterns + j;
			table[pos].offset = 0;
			//table[pos].count = 0;
			table[pos].input[0] = test_sets[j][i];
			table[pos].input[1] = 0;
			table[pos].input[2] = 0;
			table[pos].input[3] = 0;
			//table[pos].input[4] = 0;
			//printf("%d",table[pos].input[0]);
		}
		//printf("\n");
	
	}
	printf("End of init_first level logic sim\n");
}


void init_any_level(int lev,THREADPTR table)
{
	GATEPTR cg,hg,pg;
	int i,j,k,l,gatepos,m;
	register int pos;
	int epipedo;
	int offset,array,arr;

	//for all the gates of the lev level
	for (i = 0; i<=event_list[lev].last; i++) {
		cg = event_list[lev].list[i];

		//offset = find_offset(cg);
		//printf("%s\n",cg->symbol->symbol);
		//koita tis inlist kai pare th thesh twn pulwn apo tis opoies tha diavasoume

		for (k = 0; k<cg->ninput; k++) {
			hg = cg->inlis[k];
			epipedo = hg->level;
			gatepos = hg->level_pos;

			//opts
			array=gatepos*patterns;
			arr = i*patterns;

			//for all the patterns for this gate
			for ( j = 0; j<patterns; j++) {
				pos = arr + j;
				table[pos].offset = cg->offset;
				table[pos].input[k] = result_tables[epipedo][array+j].output;
			}
		}
	}
}


////////////////////////////////////////////////////////////////////////




void allocate_and_init () 
{
	int i,j;
	
	//allocates memory for the threaddata result struct of each gate
	for (i = 0; i<nog; i++) {
		net[i]->threadData = (THREADTYPE *)xmalloc(patterns*sizeof(THREADTYPE));
		net[i]->result = (RESULTYPE *)xmalloc(patterns*sizeof(RESULTYPE));
		for ( j = 0; j<patterns; j++) {
			if ((net[i]->fn == PI) || (net[i]->fn == PO) || (net[i]->fn == NOT))
				net[i]->threadData[j].offset = net[i]->fn;
			else
				net[i]->threadData[j].offset = find_offset (net[i]);
		}
    }
    
    
	//puts the pattern values into the thread structs
	for (i = 0; i<nog; i++) {
		if (net[i]->level == 0) {
			for ( j = 0; j<patterns; j++) {
				net[i]->threadData[j].input[0] = test_set[j][i] - '0';
				net[i]->threadData[j].input[1] = 0;
				net[i]->threadData[j].input[2] = 0;
				net[i]->threadData[j].input[3] = 0;
			}
		}
		else break;
	}
	
	
	//Memory checks
	//printf("Gates fn  data\n");
	//for (i = 0; i<nog; i++) {
		//if (net[i]->level == 0) {
			//printf("%s  %d ",net[i]->symbol->symbol,net[i]->fn);
			//for (j = 0; j<patterns; j++) {
				//printf("%d",net[i]->threadData[j].input[0]);
			//}
			//printf("\n");
		//}
	//}
	
	
}

*/



char getvector (FILE* file, char* s)
{
	register char c;
    int flag = 0;
    int comm = 0;

    while ((c = getc (file)) != EOF) {
	    if(is_comment(c)) { comm=1; continue; }
		if(comm==1) {
			if(c=='\n') comm=0;
			continue;
		}
		if (!flag) {
			if (is_delimiter(c)) flag = 1;
			continue;
		}
		else {
			if ( c != '\n') {
				*s++ = c;
			}
			else if ( c == '\n') {
				flag = 0;
				break;
			}
		}
	}
	
	*s = '\0';
    return(c);
}
