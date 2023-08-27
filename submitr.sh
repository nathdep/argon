#!/bin/bash

prompt_queue() {
    echo "Please select a queue by typing its number and pressing ENTER:"
    echo "1. all.q"
    echo "2. UI"
    echo "3. UI-HM"
    echo "4. Other"

    read -p "Queue selection: " queue_selection
    case $queue_selection in
        1) queue="all.q";;
        2) queue="UI";;
        3) queue="UI-HM";;
        4) read -p "Please enter the name of the desired queue: " queue;;
        *) echo "Invalid selection. Please try again." && return 1;;
    esac
    return 0
}

prompt_cores() {
    while true; do
        read -p "Please enter the number of cores to request: " cores
        if [[ ! $cores =~ ^[1-9][0-9]*$ ]]; then
            echo "Invalid input. Please enter a positive integer for cores."
        else
            break
        fi
    done
}

prompt_tasks() {
    while true; do
        read -p "Please enter the desired number of task replications: " task
        if [[ ! $task =~ ^[1-9][0-9]*$ ]]; then
            echo "Invalid input. Please enter a positive integer for tasks."
        else
            break
        fi
    done
}


prompt_directory() {
    local last_used_dir_file="$HOME/.last_used_directory"
    local last_used_dir=""
    
    # Check if the .last_used_directory file exists and read the directory from it
    if [[ -f $last_used_dir_file ]]; then
        last_used_dir=$(cat $last_used_dir_file)
        if [[ -d $last_used_dir ]]; then
            while true; do
                read -p "Last used directory was $last_used_dir. Would you like to use it again? (yes/no or y/n): " use_last_dir
                case $use_last_dir in
                    [yY]|[yY][eE][sS])
                        path=$last_used_dir
                        return
                        ;;
                    [nN]|[nN][oO])
                        break
                        ;;
                    *)
                        echo "Invalid response. Please answer with 'yes', 'no', 'y', or 'n'."
                        ;;
                esac
            done
        fi
    fi
    
    # If the above conditions aren't met or the user answers 'no', then prompt for a new directory
    while true; do
        read -p "Please specify the directory path where the R scripts are located: " path
        if [[ -d $path ]]; then
            # Save the directory to .last_used_directory for future use
            echo "$path" > $last_used_dir_file
            break
        else
            echo "Invalid directory. Please try again."
        fi
    done
}



prompt_R_directory() {
    while true; do
        read -p "Is your R file located in $path? (yes/no or y/n): " different_dir_choice
        if [[ $different_dir_choice == "no" || $different_dir_choice == "n" ]]; then
            read -p "Enter the new directory path: " path
            break
        elif [[ $different_dir_choice == "yes" || $different_dir_choice == "y" ]]; then
            break
        else
            echo "Invalid response. Please answer with 'yes' or 'no' (or 'y'/'n')."
        fi
    done
}

prompt_R_file() {
    while true; do
        echo "Available R files in $path:"
        mapfile -t r_files < <(find $path -type f -name "*.R")
        if [[ ${#r_files[@]} -eq 0 ]]; then
            echo "No R files found in the specified directory."
            read -p "Please specify a different directory: " path
            continue
        else
            for i in "${!r_files[@]}"; do
                echo "$((i+1)). $(basename ${r_files[$i]})"
            done
            break
        fi
    done

    while true; do
        read -p "Enter the number corresponding to your desired R file: " r_file_selection
        if [[ $r_file_selection =~ ^[0-9]+$ && $r_file_selection -ge 1 && $r_file_selection -le ${#r_files[@]} ]]; then
            Rfile="${r_files[$((r_file_selection-1))]}"
            break
        else
            echo "Invalid selection. Please select a number from the provided list."
        fi
    done
}

prompt_localscratch() {
    while true; do
        read -p "Do you require a high amount of free localscratch memory to complete the job? (y/n): " need_memory
        case $need_memory in
            [yY]|[yY][eE][sS])
                while true; do
                    read -p "How much free memory is needed (in GB)? " size
                    if [[ ! $size =~ ^[1-9][0-9]*$ ]]; then
                        echo "Invalid input. Please enter a positive integer for memory size."
                    else
                        break
                    fi
                done
                break
                ;;
            [nN]|[nN][oO])
                size="no additional localscratch memory indicated"
                break
                ;;
            *)
                echo "Invalid response. Please answer with 'y' or 'n'."
                ;;
        esac
    done
}

prompt_gpu() {
    while true; do
        read -p "Do you need to use a GPU in your job? (y/n): " need_gpu
        case $need_gpu in
            [yY]|[yY][eE][sS])
                while true; do
                    read -p "How many GPUs are needed? " ngpus
                    if [[ ! $ngpus =~ ^[1-9][0-9]*$ ]]; then
                        echo "Invalid input. Please enter a positive integer for GPU count."
                    else
                        break
                    fi
                done
                break
                ;;
            [nN]|[nN][oO])
                ngpus="no gpus indicated"
                break
                ;;
            *)
                echo "Invalid response. Please answer with 'y' or 'n'."
                ;;
        esac
    done
}


# Default values
queue=""
cores=""
task=""
path=""
Rfile=""
localscratch_free=""
ngpus=""

# Process command-line flags
while getopts ":q:c:t:p:r:s:g:h" opt; do
  case $opt in
    q) queue="$OPTARG";;
    c) cores="$OPTARG";;
    t) task="$OPTARG";;
    p) path="$OPTARG";;
    r) Rfile="$OPTARG";;
    s) localscratch_free="$OPTARG";;
    g) ngpus="$OPTARG";;
    h) 
       echo "Usage: submitr2.sh [options]"
       echo "Options:"
       echo "   -q <queue_name>          Specify queue name (default: all.q)"
       echo "   -c <num_of_cores>        Specify number of cores"
       echo "   -t <num_of_tasks>        Specify number of task replications"
       echo "   -p <path>                Specify target directory"
       echo "   -r <R_file_path>         Specify R file path"
       echo "   -s <localscratch_size>   Specify localscratch memory (in GB)"
       echo "   -g <num_of_gpus>         Specify number of GPUs needed"
       echo "   -h                       Display this help message"
       exit 0;;
    \?) echo "Invalid option -$OPTARG" >&2; exit 1;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1;;
  esac
done

# If not set by command-line flags, ask the user
if [[ -z $queue ]]; then prompt_queue; fi
if [[ -z $cores ]]; then prompt_cores; fi
if [[ -z $task ]]; then prompt_tasks; fi
if [[ -z $path ]]; then prompt_directory; fi
if [[ -z $Rfile ]]; then 
    prompt_R_directory
    prompt_R_file
fi
if [[ -z $localscratch_free ]]; then prompt_localscratch_memory; fi
if [[ -z $ngpus ]]; then prompt_gpu; fi

# Beginning of the main loop
while true; do
    prompt_queue || continue
    prompt_cores
    prompt_tasks
    prompt_localscratch
    prompt_gpu
    prompt_directory
    prompt_R_directory
    prompt_R_file

    # Display the summary before submission
    clear
    echo "Summary of your selections:"
    echo "---------------------------"
    echo "Selected Queue: $queue"
    echo "Number of Cores: $cores"
    echo "Number of Task Replications: $task"
    echo "Target Directory: $path"
    echo "R File Path: $Rfile"
    echo "Local Scratch Free Memory: $localscratch_free"
    echo "GPUs needed: $ngpus"
    echo "---------------------------"

    read -p "Would you like to proceed (p/y/yes), modify a response (m), or exit (e/n/no)? " choice

    case $choice in
        p|y|yes) break;;
        m) 
            echo "Which selection would you like to modify?"
            echo "1. Queue"
            echo "2. Number of Cores"
            echo "3. Number of Tasks"
            echo "4. Target Directory"
            echo "5. R File Directory"
            echo "6. R File"
            read -p "Enter your choice: " modify_choice
            case $modify_choice in
                1) prompt_queue;;
                2) prompt_cores;;
                3) prompt_tasks;;
                4) prompt_directory;;
                5) prompt_R_directory;;
                6) prompt_R_file;;
                *) echo "Invalid selection. Please try again.";;
            esac
            ;;
        e|n|no) kill -TSTP $$;;
        *) echo "Invalid choice. Please choose 'p', 'y', 'yes', 'm', 'e', 'n', or 'no'.";;
    esac
done

# Check if directory "e" exists; if not, create it
if [[ ! -d $path/e ]]; then
    echo "WARNING: Error directory not found. Making new directory 'e' in target directory."
    mkdir $path/e
fi

# Check if directory "o" exists; if not, create it
if [[ ! -d $path/o ]]; then
    echo "WARNING: Output directory not found. Making new directory 'o' in target directory."
    mkdir $path/o
fi

seed=$(date +%s)

# Modify the error and output file paths to prevent overwriting
error_path="$path/e/error_$seed.$SGE_TASK_ID"
output_path="$path/o/output_$seed.$SGE_TASK_ID"

# Assemble the job script contents
job_script="#!/bin/bash
#$ -q $queue
#$ -pe smp $cores
$localscratch_directive
$gpu_directive
#$ -e $error_path
#$ -o $output_path

cd $path
apptainer exec $HOME/cmd.sif Rscript --vanilla $Rfile $SGE_TASK_ID"

# Save the job script to a file
echo "$job_script" > $path/rjob$seed.sh

# Submit the job using qsub
qsub -t 1-$task $path/rjob$seed.sh $SGE_TASK_ID && rm $path/rjob$seed.sh
