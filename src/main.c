#include <getopt.h>
#include <time.h>
#include <sys/time.h>
#include "define.h"
#include "my_cuda.h"

const char* circuit_name;
const char* fault_name;
const char* vectors_name;
int nodummy;
int next_level_length;
char test_name[100]="";

int* LUT;
FILE *circuit_fd, *fault_fd, *vectors_fd,*test_fd;

/* Description of long options for get_opt long */
static const struct option long_options[] = {
    { "help",       0, NULL, 'h' },
    { "circuit",    1, NULL, 'c' },
    { "vector",     1, NULL, 'v' },
    { "fault",      1, NULL, 'f' },
    { "random",     1, NULL , 'r'},
    { "log",        1, NULL, 'l' }
};

static const char* const short_options = "hc:v:f:r:l:";
static void print_usage (int is_error);

static const char* const usage_template = 
    "Usage: %s [ options ]\n"
    "   -h, --help          Print this information\n"
    "   -c, --circuit FILE  Read the circuit file\n"
    "   -v, --vectors FILE  Read the test-pattern file\n"
    "   -f, --fault FILE    Read the fault file\n"
    "   -r, --random NUMBER Create random test patterns\n"
    "   -l, --log FILE      Create a log file\n";



int main (int argc, char* const argv[])
{
	int i,j,k;
	char c;
	nodummy = 0;
    program_name = argv[0];
	double u1, u2, u3, u4, total  =  0;
	double total1 = 0;
	struct timeval tv;
    
    /*******************************************************************
     * 						Make the structures
     * ****************************************************************/
    
    /* Get the input arguments */
    option_set(argc,argv);
    
    /* Handle the input files */
    handle_files (circuit_name,vectors_name);
    
    /* Start the timer for the data structures */
    gettimeofday(&tv,NULL);
   	u1 = tv.tv_sec*1.0e6 + tv.tv_usec;

		/* Read the circuit file and make the structures */
    	if (read_circuit (circuit_fd) < 0)
    		system_error ("read_circuit");
    	fclose (circuit_fd);
    
    	if (nog<=0 || nopi<=0 || nopo<=0) {
    		fprintf(stderr,"Error in circuit file: #PI=%d, #PO=%d, #GATES=%d\n",nopi,nopo,nog);
    		abort();
    	}
    
    	/* Add a gate for the output stage as you did for the input stage */
    	nodummy = add_PO();
    
    	/* Compute the levels of the circuit */
    	allocate_stacks();
    	maxlevel = compute_level();
    	/* Place the PO at the last level */
    	place_PO();

    	printf("the max level = %d\n",maxlevel);
    
    	/* Computes the level of each gate */
    	allocate_event_list();
    	/* Levelize the circuit */
    	levelize();
    	//xfree(event_list);
    
    /* Stop the timer */
    gettimeofday(&tv,NULL);
    u2 = tv.tv_sec*1.0e6 + tv.tv_usec;
    total=(u2-u1);
    printf("Time for construction of data structures: %f usec\n", total);
    total = 0;
    
    
    
    /*******************************************************************
     * 				Read the test patterns and make the tables
     * ****************************************************************/
    
    
    /* Open the vector file */
	printf("opening vectors file= %s\n",vectors_name);
    vectors_fd = fopen (vectors_name, "r");
	if (vectors_fd == NULL)
		system_error ("fopen");
		


	/* Read the vector file and put the input values to the INPUT GATES */
	if (read_vectors (vectors_fd,vectors_name) != 0)
		system_error ("read_vectors");
	
	

	/*******************************************************************
	 * 						Logic simulation
	 * ****************************************************************/
	/* Start the timer  for the Logic simulation*/
	gettimeofday(&tv,NULL);
   	u1 = tv.tv_sec*1.0e6 + tv.tv_usec;
	
		/*logic simulation here for cuda*/
   		LUT = create_lut (LUT);
   		device_allocations();
   		dummy_gpu(0);
   		//printf("\ngpu data from first level computed ready\n");
   		for (k = 1; k<maxlevel; k++) {
   			init_any_level(k,cuda_tables[k]);
   			//printf("data for %d level ready\n",k);
   			dummy_gpu(k);
   		}


	//logic_sim();

	/*i=0; j=0;
	if(test_name[0]=='\0') {
		while((c=circuit_name[i++])!='\0') {
			if(c=='/') j=0;
			else if(c=='.') break;
			else test_name[j++]=c;
		}
		test_name[j]='\0';
		strcat(test_name,".test");
	} */

	gettimeofday(&tv,NULL);
    u2 = tv.tv_sec*1.0e6 + tv.tv_usec;
    total=(u2-u1);

    printf("\nCPU Time for logic simulation: %f usec\n", total);
    total= 0;


    device_deallocations();

    //print_logic_sim();
	
	


	/*******************************************************************
	 * 						Fault simulation
	 * ****************************************************************/

    /* fault simulation for cuda here */
    //tha mporoume na thn pairnoume kai etoimh thn fault list

    //creates the fault list only for faults at the output of the gates
    //and not for the branches
	create_fault_list ();
	//print_fault_list();
	//mnhmh sth RAM gia ta arxika sfalmata



	allocate_cuda_faultables();

	allocate_TFO_lists();

	/* Start the timer for the fault simulation*/
	gettimeofday(&tv,NULL);
   	u1 = tv.tv_sec*1.0e6 + tv.tv_usec;

		//ftiaxnei ton pinaka gia to cuda me ta sfalmata ola osa den einai PO
		init_faultable(fault_tables[0]);

	gettimeofday(&tv,NULL);
    u2 = tv.tv_sec*1.0e6 + tv.tv_usec;
    total=(u2-u1);
    printf("Fisrt level of scheduling completed %f\n",total);
    total = 0;

	//mnhmh sto GPU
	device_allocations2();

	/* Start the timer */
	gettimeofday(&tv,NULL);
   	u1 = tv.tv_sec*1.0e6 + tv.tv_usec;

		//ektelesh 1ou epipedou
		dummy_gpu2(0);

		//ypologise kwno
		//allocate_TFO_lists();
		compute_TFO();
	gettimeofday(&tv,NULL);
	u2 = tv.tv_sec*1.0e6 + tv.tv_usec;
	total=(u2-u1);
	printf("Fisrt level of fault sim completed %f\n",total);
	total = 0;
	//kaleitai prin apo kathe init any level
	//next_level_length = compute_length();
	//printf("plhthos %d\n",next_level_length);
	//allocate_next_level(next_level_length, 1);
	//init_anylevel_faultable(1, fault_tables[1], detect_tables);


	for (k = 1; k<maxlevel-2; k++) {

		next_level_length = compute_length();
		//printf("plhthos %d\n",next_level_length*patterns);
		allocate_next_level(next_level_length, k);
		init_anylevel_faultable(k, fault_tables[k]);
		//printf("data for %d level ready\n",k);

		/* Start the timer */

		gettimeofday(&tv,NULL);
	   	u3 = tv.tv_sec*1.0e6 + tv.tv_usec;
		dummy_gpu2(k);
		gettimeofday(&tv,NULL);
	    u4 = tv.tv_sec*1.0e6 + tv.tv_usec;
	    total1 = total1 + (u4-u3);
	    printf("xronos gia CUDA %f\n",total1);
	}

	//gettimeofday(&tv,NULL);
    //u2 = tv.tv_sec*1.0e6 + tv.tv_usec;
    //total = total + (u2-u1);

	device_deallocations2();

	/* Start the timer */
	gettimeofday(&tv,NULL);
   	u1 = tv.tv_sec*1.0e6 + tv.tv_usec;

	detect_index = compute_detected();
	//printf("Length of detetct array %d\n",detect_index);
	allocate_detect_goodsim(detect_index);
	prepare_detection(GoodSim, detect_tables);

	gettimeofday(&tv,NULL);
    u2 = tv.tv_sec*1.0e6 + tv.tv_usec;
    total =  (u2-u1);
    printf("Prepared the detectuion schedule %f\n",total);

	//Call the detetction
	device_allocations3();

	/* Start the timer */
	gettimeofday(&tv,NULL);
   	u1 = tv.tv_sec*1.0e6 + tv.tv_usec;

   	printf("hell dummy3\n");
	dummy_gpu3();

	gettimeofday(&tv,NULL);
    u2 = tv.tv_sec*1.0e6 + tv.tv_usec;
    total =  (u2-u1);
	device_deallocations3();

    printf("\nCPU Time for fault simulation: %f usec\n", total);


	//gettimeofday(&tv,NULL);
   	//u1 = tv.tv_sec*1.0e6 + tv.tv_usec;





	//<----------------------------------------------------------------
	//fault simulation here
	//gettimeofday(&tv,NULL);
   	//u1 = tv.tv_sec*1.0e6 + tv.tv_usec;	
	
	//create_fault_list ();
	//print_fault_list();
	//fault_sim();
	
	//gettimeofday(&tv,NULL);
    //u2 = tv.tv_sec*1.0e6 + tv.tv_usec;
    
    //total=(u2-u1);
    
    //printf("Time for fault simulation: %f usec\n", total);
    //total= 0;
	
	
	
	/*if ( fault_name == NULL ) {
		printf("\nWe are done\n");
		return 0;
	}
	
	printf("opening fault file= %s\n",fault_name);
    vectors_fd = fopen (vectors_name, "r");
	if (vectors_fd == NULL)
		system_error ("fopen"); */
	
	
		
	//	synexeia simulation<-----------------------------------
    
    
    
    printf("\nWe are done\n");
    return 0;
}




void option_set (int argc, char* const argv[])
{	
	int next_option;

    do {
        next_option = 
            getopt_long (argc, argv, short_options, long_options, NULL);
        switch (next_option) {
            case 'c':
                circuit_name = optarg;
				break;
			case 'v':
				vectors_name = optarg;
				break;
            case 'f':
                fault_name = optarg;               
				break;
			case 'r': //needs fix
				break;
			case 'l': //needs fix
				break;
            case 'h':
                print_usage (0);
                break;
            case '?':
                print_usage (1);
                break;
            case -1:
				if (argc > 1)
					break;
                else
					print_usage (0);
					break;
            default:
                abort ();
        }
    } while (next_option != -1);

    if (optind != argc)
        print_usage (1);
}




void handle_files (const char* circuit_name,const char* vectors_name)
{
	if ((circuit_name != NULL) & (vectors_name != NULL) ) {
        printf("opening circuit file= %s\n",circuit_name);
        circuit_fd = fopen (circuit_name, "r");
		if (circuit_fd == NULL)
			system_error ("fopen");
	}
	else {
		fprintf (stderr, "You must give a circuit file and a test pattern file first\n");
		exit(1);
	}
			
}




static void print_usage (int is_error)
{
    fprintf (is_error ? stderr : stdout, usage_template, program_name);
    exit (is_error ? 1 : 0);
}

