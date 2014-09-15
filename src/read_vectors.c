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

 
	return 0;
	
}


void Compute_gates(){
	int i;

	for (i = 0; i< maxlevel-1; i++){
		total_gates = total_gates + levels[i];
	}
	result_tables = xmalloc ( total_gates*patterns*sizeof(RESULTYPE));

}




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
