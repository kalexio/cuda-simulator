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
	int length,detected;
    
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
     * 		Read the test patterns and prepare the data to send
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


	//Create the LUT table
	LUT = create_lut (LUT);
	
	//Total real gates of the circuit
	Compute_gates();

	printf("The gates are computed\n");
	//allocation of memory for:
	//1. LUT, 2. Cuda vectors, 3.Cuda results, 4.Cuda structs
	//and memcpy for LUT and Cuda vectors
	device_allocations();

	printf("memory1 allocated\n");
	//kernels for filling the structs and do the first level logic sim
	init_first_level();

	//kernels the whole Logic simulation
	init_any_level();

	//for (i = 0; i< total_gates*patterns; i++) printf("%d",result_tables[i]);


	/*******************************************************************
	 * 						Fault simulation
	 * ****************************************************************/

    //creates the fault list only for faults at the output of the gates
    //and not for the branches
	create_fault_list ();
	//print_fault_list();

	//Allocates mem in each gate for the faults pos etc.
	allocate_TFO_lists();

	//Computes for every fault how many patterns should be simulated
	//and creates an array which its every posotion points to a specific pattern
	count_fault_patterns();

	device_allocations2(tot_patterns);
	printf("memory2 allocated\n");


	fault_init_first_level();


	//make it a function
	for (i = 0; i<total_faults; i++){
		//end the faults
		if(fault_list[i].end == 2){
			fault_list[i].end = 1;
			fault_list[i].TFO_stack.list = (GATEPTR *)xmalloc(1*sizeof(GATEPTR));
			clear(fault_list[i].TFO_stack);
			push(fault_list[i].TFO_stack,fault_list[i].gate);
		}
	}
	//////////

	printf("End of first level fault\n");

	//Ypologizetai to transitive fanout kathe pulhs
	compute_TFO();
	printf("End of compute TFO\n");

	//Ypologismos tou ariyhmou twn pulwn pou ephreazei to kathe sfalma sto neo epipedo
	for (i = 1; i< maxlevel-2; i++){
		//Ypologismos tou ariyhmou twn pulwn pou ephreazei to kathe sfalma sto neo epipedo
		compute_length();
		length = fault_init_any_level();
		printf("Computed levels in %d level is %d\n",i,length);
		if (length == 0) break;
	}

	detected = compute_detected();
	printf("Length of fault detection is %d\n",detected);

	device_allocations3(detected);
	printf("memory3 allocated\n");

	//fault detetction here!!!!
	prepare_detection_table();

	device_deallocations3();
	printf("memory deallocated\n");
    
    
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

