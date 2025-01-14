#########################
#RNAseq pipeline
#########################

#author Raphael Leman r.leman@baclesse.unicancer.fr, Center François Baclesse and Normandie University, Unicaen, Inserm U1245
#Copyright 2019 Center François Baclesse and Normandie University, Unicaen, Inserm U1245

#This software was developed from the work:
#SpliceLauncher: a tool for detection, annotation and relative quantification of alternative junctions from RNAseq data.
#Raphaël Leman, Grégoire Davy, Valentin Harter, Antoine Rousselin, Alexandre Atkinson, Laurent Castéra, Dominique Vaur,
#Fréderic Lemoine, Pierre De La Grange, Sophie Krieger

#Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
#to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute,
#sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

#The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
#FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
#WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#!/bin/bash

################
#Set parameters#
################

messageHelp="Usage: $0
    \n
    [Mandatory] \n
        \t-F, --fastq /path/to/fastq/\n\t\trepository of the FASTQ files\n
        \t-O, --output /path/to/output/\n\t\trepository of the output files\n
        \t-g, --genome /path/to/genome\n\t\tpath to the STAR genome\n
        \t--STAR /path/to/STAR\n\t\tpath to the STAR executable\n
        \t--samtools /path/to/samtools\n\t\tpath to samtools executable\n
        \t--bedtools /path/to/bedtoolsFolder/\n\t\tpath to repository of bedtools executables\n
        \t--bedannot /path/to/bedannot\n\t\tpath to exon coordinates (in BED format)\n
        \t--perlscript /path/to/perlscript/\n\t\trepository of perl scripts used by the pipeline\n
        \t-t, --threads N\n\t\tNb threads used for the alignment\n
        \t-m, --memory N\n\t\tMemory used for the alignment\n
    [Options]\n
        \t-p paired-end analysis\n\t\tprocesses to paired-end analysis\n\n
        \t-B, --bam /path/to/BAM input files\n
   You could : $0 -F /path/to/FASTQfolder/ -O /path/to/output/ -g /path/to/STARgenome/ --star /path/to/STAR
   --samtools /path/to/samtools --bedtools /path/to/BEDtools/bin/ --bedannot /path/to/BEDannot"

if [ $# -lt 8 ]; then
    echo -e $messageHelp
    exit
fi

#check directory
in_error=0 #stop program if in_error = 1
endType=""


while [[ $# -gt 0 ]]; do
   key=$1
   case $key in
   
       --runMode)
       runMode="$2"
       shift 2 # shift past argument and past value
       ;;
       
       -F|--fastq)
       pathToFastq="`readlink -v -f $2`"
       shift 2 # shift past argument and past value
       ;;

       -O|--output)
       pathToRun="`readlink -v -f $2`"
       shift 2 # shift past argument and past value
       ;;

        -g|--genome)
        genomeDirectory="`readlink -v -f $2`"
        shift 2 # shift past argument and past value
        ;;
        --STAR)
        STARPath="$2"
        shift 2 # shift past argument and past value
        ;;

        --samtools)
        SamtoolsPath="$2"
        shift 2 # shift past argument and past value
        ;;

        --bedtools)
        BEDtoolsPath="$2"
        shift 2 # shift past argument and past value

        ;;
        --bedannot)
        BEDrefPath="`readlink -v -f $2`"
        shift 2 # shift past argument and past value
        ;;

        --perlscript)
        ScriptPath="`readlink -v -f $2`"
        shift 2 # shift past argument and past value
        ;;

       -t|--threads)
       threads="$2"
       shift 2 # shift past argument and past value
       ;;

       -m|--memory)
       memory="$2"
       shift 2 # shift past argument and past value
       ;;
       
       -p)
       endType="paired"
       shift # shift past argument
       ;;
       
       -B|--bam)
       bam_path="`readlink -v -f $2`"
       shift 2 # shift past argument and past value
       ;;
       
       *)  # unknown option
       POSITIONAL+=("$key") # save it in an array for later
       echo -e "    Unknown option ${key}"
       shift # shift past argument
      ;;
   esac
done

# echo "RunMode = ${runMode}"

if [[ ${runMode} = "Align" ]]; then

    bam_path="${pathToRun}/Bam"
    mkdir -p ${bam_path}

    ###############################################################
    ########################## Alignment ##########################
    ###############################################################

    echo "####Your options:"
    echo -e "    path to fastq = ${pathToFastq}"
    echo -e "    path to output = ${pathToRun}"
    echo -e "    path to STAR genome files = ${genomeDirectory}"
    echo -e "    path to STAR = ${STARPath}"
    echo -e "    path to samtools = ${SamtoolsPath}"
    echo -e "    threads = ${threads}"
    echo -e "    memory = ${memory}"
    echo -e "    end type analysis = ${endType}"

    echo "####Check your options"
    for directory in ${pathToFastq} ${genomeDirectory}; do
        if [ ! -d $directory ]
        then
            echo -e "****You must define the directory : ${directory}****"
            ${in_error}=1
        else
            echo "    The directory: ${directory}... OK"
        fi
    done

    #check the softs
    for soft in ${SamtoolsPath} ${STARPath}; do
        command -v ${soft} >/dev/null 2>&1 || { in_error=1; echo >&2 "****${soft} is required but it's not installed. Aborting.****";}
    done

    if [ ${in_error} -eq 1 ]; then
        echo -e $messageHelp
        exit 1;
    else
        echo "    The Samtools soft: ${SamtoolsPath}... OK"
        echo "    The STAR soft: ${STARPath}... OK"
    fi

    ###########################
    # Alignment STAR
    ###########################

    echo "###### Alignment process ######"

    cd ${pathToFastq}

    echo "##### FASTQ files ######"
    ls -lh *.fastq.gz

    # unload genome reference of any last run
    ${STARPath} --genomeDir ${genomeDirectory} --genomeLoad Remove > /dev/null 2>&1 || true

    if [[ ${endType} = "paired" ]]
    then
        #paired-end
        for file in *_R1_001.fastq.gz; do
            if [ -e $file ]
            then
                echo "treatment of $file..."
                ${STARPath} \
                    --outSAMstrandField intronMotif \
                    --outFilterMismatchNmax 2 \
                    --outFilterMultimapNmax 10 \
                    --genomeDir ${genomeDirectory} \
                    --readFilesIn $file ${file%_R1_001.fastq.gz}_R2_001.fastq.gz\
                    --readFilesCommand zcat \
                    --runThreadN ${threads} \
                    --outSAMunmapped Within \
                    --outSAMtype BAM SortedByCoordinate \
                    --limitBAMsortRAM ${memory} \
                    --outSAMheaderHD \@HD VN:1.4 SO:SortedByCoordinate \
                    --outFileNamePrefix ${bam_path}/${file%_R1_001.fastq.gz}. \
                    --genomeLoad LoadAndKeep > ${bam_path}/${file%_R1_001.fastq.gz}.log 2>&1
            else
                echo -e "****the file $file doesn't exist, Please rename your file in XXXXX_R1(2)_001.fastq.gz format****\n****XXXXX_R1_001.fastq.gz for R1 read and XXXXX_R2_001.fastq.gz for R2 read****\n"
                echo -e $messageHelp
                exit
            fi
        done
    else
        #single-end
        for file in *.fastq.gz; do
            if [ -e $file ]
            then
                echo "treatment of $file..."
                ${STARPath} \
                    --outSAMstrandField intronMotif \
                    --outFilterMismatchNmax 2 \
                    --outFilterMultimapNmax 10 \
                    --genomeDir ${genomeDirectory} \
                    --readFilesIn $file \
                    --readFilesCommand zcat \
                    --runThreadN ${threads} \
                    --outSAMunmapped Within \
                    --outSAMtype BAM SortedByCoordinate \
                    --limitBAMsortRAM 15000000000 \
                    --outSAMheaderHD \@HD VN:1.4 SO:SortedByCoordinate \
                    --outFileNamePrefix ${bam_path}/${file%.fastq.gz}. \
                    --genomeLoad LoadAndKeep > ${bam_path}/${file%.fastq.gz}.log 2>&1
            else
                echo "****the file $file doesn't exist, Please rename your file in XXXXX.fastq.gz****"
                echo -e $messageHelp
                exit
            fi
        done
    fi
    # unload genome reference from shared memory
    ${STARPath} --genomeDir ${genomeDirectory} --genomeLoad Remove

    echo "###### Make BAM index ######"

    cd $bam_path
    ls -lh *.bam
    for file in *sortedByCoord.out.bam; do
        echo "treatment of $file..."
        ${SamtoolsPath} index $file
    done
fi

if [[ ${runMode} = "Count" ]]; then
    runName=`basename $pathToRun`

    ###############################################################
    ############################ Count ############################
    ###############################################################

    echo "####Your options:"
    echo -e "    path to output = ${pathToRun}"
    echo -e "    path to input = ${bam_path}"
    echo -e "    path to samtools = ${SamtoolsPath}"
    echo -e "    path to bedtools = ${BEDtoolsPath}"
    echo -e "    path to the bed annot file = ${BEDrefPath}"
    echo -e "    path to perl scripts = ${ScriptPath}"
    echo -e "    name of run = ${runName}"
    echo -e "    threads = ${threads}"
    echo -e "    end type analysis = ${endType}"

    echo "####Check your options"
    for directory in ${bam_path}; do
        if [ ! -d $directory ]
        then
            echo -e "****You must define the directory : ${directory}****"
            ${in_error}=1
        else
            echo "    The directory: ${directory}... OK"
        fi
    done
    
    #check the softs
    for soft in ${SamtoolsPath} \
     "${ScriptPath}/bedBlocks2IntronsCoords.pl" \
     "${ScriptPath}/joinJuncFiles.pl" \
     "${BEDtoolsPath}"; do \
        command -v ${soft} >/dev/null 2>&1 || { ${in_error}=1; echo >&2 "****The ${soft} is required but it's not installed. Aborting.****";}
    done
    
    #check BED exon annotation
    if [ ! -e ${BEDrefPath} ]
    then
       echo -e "****We cannot find the bedtools annot file at ${BEDrefPath}****"
       ${in_error}=1
    else
        echo "    The bedtools annot file: ${BEDrefPath}... OK"
    fi
    
    if [ ${in_error} -eq 1 ]; then
        echo -e $messageHelp
        exit 1;
    else
        echo "    The Samtools soft: ${SamtoolsPath}... OK"
        echo "    The perl Scripts: ${ScriptPath}... OK"
        echo "    The BEDtools soft: ${BEDtoolsPath}... OK"
    fi
    
    #####################
    #Creating BED files
    #####################
    echo "###### Make BED files and junction count ######"

    ClosestExPath="${pathToRun}/getClosestExons"
    mkdir -p ${ClosestExPath}

    cd $bam_path

    if [[ ${endType} = "paired" ]]
    then
        for file in *.Aligned.sortedByCoord.out.bam; do
            echo "treatment of $file for forward read..."
            ${SamtoolsPath} view -b -f 0x40 $file | \
                ${BEDtoolsPath} bamtobed -bed12 -i stdin | \
                awk '{if($10>1){print $0}}' | \
                perl ${ScriptPath}/bedBlocks2IntronsCoords.pl y - | \
                awk '{if($5==255){print $0}}'  > ${file%.Aligned.sortedByCoord.out.bam}_juncs.bed
            echo "treatment of $file for reverse read..."
            ${SamtoolsPath} view -b -f 0x80 $file | \
                ${BEDtoolsPath} bamtobed -bed12 -i stdin | \
                awk '{if($10>1){print $0}}' | \
                perl ${ScriptPath}/bedBlocks2IntronsCoords.pl n - | \
                awk '{if($5==255){print $0}}'  >> ${file%.Aligned.sortedByCoord.out.bam}_juncs.bed
        done

        echo "###### count junctions ######"
        for file in *_juncs.bed; do
            echo "treatment of $file..."
            sort -k1,1 -k2,2n $file | \
                uniq -c | \
                awk 'BEGIN{OFS="\t"}{print $2,$3,$4,$5 "_" $1,$6,$7}' | \
                ${BEDtoolsPath} closest -d -t first -a stdin -b ${BEDrefPath} | \
                awk 'BEGIN{OFS="\t"}{if($13<200){print $0}else{print $1,$2,$3,$4,$5,$6,".","-1","-1",".","-1",".","-1" }}' | \
                awk 'BEGIN{OFS="\t"}{if($8>0){split($4,counts,"_"); split($10,nm,"|");print $1,$2,$3,$6,nm[1],counts[1],counts[2],counts[3],counts[4]}}' \
                >  ${ClosestExPath}/${file%_juncs.bed}.txt
        done
    else
        for file in *.Aligned.sortedByCoord.out.bam; do
            echo "treatment of $file..."
            ${BEDtoolsPath} bamtobed -bed12 -i $file | \
                awk '{if($10>1){print $0}}' | \
                perl ${ScriptPath}/bedBlocks2IntronsCoords.pl y - | \
                awk '{if($5==255){print $0}}' | \
                sort -k1,1 -k2,2n | \
                uniq -c | \
                awk 'BEGIN{OFS="\t"}{print $2,$3,$4,$5 "_" $1,$6,$7}' | \
                tee ${ClosestExPath}/${file%.Aligned.sortedByCoord.out.bam}.sort_count.bed | \
                ${BEDtoolsPath} closest -d -t first -a stdin -b ${BEDrefPath} | \
                awk 'BEGIN{OFS="\t"}{if($13<200){print $0}else{print $1,$2,$3,$4,$5,$6,".","-1","-1",".","-1",".","-1" }}' | \
                awk 'BEGIN{OFS="\t"}{if($8>0){split($4,counts,"_"); split($10,nm,"|");print $1,$2,$3,$6,nm[1],counts[1],counts[2],counts[3],counts[4]}}' \
                >  ${ClosestExPath}/${file%.Aligned.sortedByCoord.out.bam}.count
        done
    fi

    #######################
    #Final count
    #######################
    echo "###### Merge the junction counts ######"

    cd $ClosestExPath

    perl ${ScriptPath}/joinJuncFiles.pl *.count > ${pathToRun}/${runName}.txt

fi

echo "###### Finished! ######"
