workflow ChromoseqAnalysis {

  String Cram
  String CramIndex 
  String Name
  String Gender
  String Exception
  String MappingSummary
  String? CoverageSummary
  String TumorCounts
  String OutputDir
  
  String Translocations
  String GenesBed
  
  String Cytobands
  String SVDB

  String CustomAnnotationVcf 
  String CustomAnnotationIndex
  String CustomAnnotationParameters
  String? GeneFilterString
  
  String HotspotVCF
  String MantaConfig
  String MantaRegionConfig
  
  String HaplotectBed
  
  String Reference
  String ReferenceDict
  String ReferenceIndex
  String ReferenceBED
  String VEP

  String gcWig
  String mapWig
  String ponRds
  String centromeres
  String genomeStyle
  String genome

  String RefRangeJSON
  String RunInfoString
  String tmp
  
  Float minVarFreq
  Int MinReads
  Float varscanPvalindel
  Float varscanPvalsnv

  Int CNAbinsize = 500000
  Int MinCNASize = 5000000
  Float MinCNAabund = 10.0

  Int MinValidatedReads
  Float MinValidatedVAF

  Int MinCovFraction
  Int MinGeneCov
  Int MinRegionCov
  
  String JobGroup
  String Queue

  String chromoseq_docker

  call prepare_bed {
    input: Bedpe=Translocations,
    Bed=GenesBed,
    Reference=ReferenceBED,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }

  call cov_qc as gene_qc {
    input: Cram=Cram,
    CramIndex=CramIndex,
    Name=Name,
    Bed=GenesBed,
    refFasta=Reference,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }

  call cov_qc as sv_qc {
    input: Cram=Cram,
    CramIndex=CramIndex,
    Name=Name,
    Bed=prepare_bed.svbed,
    refFasta=Reference,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }
  
  call run_manta {
    input: Bam=Cram,
    BamIndex=CramIndex,
    Config=MantaConfig,
    Reference=Reference,
    ReferenceBED=ReferenceBED,
    Name=Name,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }

  call run_ichor {
    input: Bam=Cram,
    BamIndex=CramIndex,
    refFasta=Reference,
    ReferenceBED=ReferenceBED,
    tumorCounts=TumorCounts,
    gender=Gender,
    gcWig=gcWig,
    mapWig=mapWig,
    ponRds=ponRds,
    centromeres=centromeres,
    Name=Name,
    genomeStyle=genomeStyle,
    genome=genome,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }
  
  call run_varscan_indel {
    input: Bam=Cram,
    BamIndex=CramIndex,
    CoverageBed=GenesBed,
    MinFreq=minVarFreq,
    pvalindel=varscanPvalindel,
    refFasta=Reference,
    Name=Name,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }

  call run_varscan_snv {
    input: Bam=Cram,
    BamIndex=CramIndex,
    CoverageBed=GenesBed,
    MinFreq=minVarFreq,
    pvalsnv=varscanPvalsnv,
    refFasta=Reference,
    Name=Name,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }
  
  call run_manta_indels {
    input: Bam=Cram,
    BamIndex=CramIndex,
    Reg=GenesBed,
    Config=MantaRegionConfig,
    refFasta=Reference,
    Name=Name,
    genome=genome,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }

  call run_pindel_indels {
    input: Bam=Cram,
    BamIndex=CramIndex,
    Reg=GenesBed,
    refFasta=Reference,
    Name=Name,
    genome=genome,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }

  call combine_variants {
    input: VCFs=[run_varscan_snv.vcf,
    run_varscan_indel.vcf,run_pindel_indels.vcf,
    run_manta_indels.vcf,
    HotspotVCF],
    MinVAF=minVarFreq,
    MinReads=MinReads,
    Bam=Cram,
    BamIndex=CramIndex,
    refFasta=Reference,
    Name=Name,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }
  
  call annotate_variants {
    input: Vcf=combine_variants.combined_vcf_file,
    refFasta=Reference,
    Vepcache=VEP,
    Cytobands=Cytobands,
    CustomAnnotationVcf=CustomAnnotationVcf,
    CustomAnnotationIndex=CustomAnnotationIndex,
    CustomAnnotationParameters=CustomAnnotationParameters,
    FilterString=GeneFilterString,
    Name=Name,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }
  
  call annotate_svs {
    input: Vcf=run_manta.vcf,
    CNV=run_ichor.seg,
    refFasta=Reference,
    refFastaIndex=ReferenceIndex,
    Vepcache=VEP,
    SVAnnot=SVDB,
    Translocations=Translocations,
    Cytobands=Cytobands,
    minCNAsize=MinCNASize,
    minCNAabund=MinCNAabund,
    Name=Name,
    gender=Gender,
    queue=Queue,
    jobGroup=JobGroup,
    tmp=tmp,
    docker=chromoseq_docker
  }
  
  call run_haplotect {
    input: refFasta=Reference,
    refDict=ReferenceDict,
    Cram=Cram,
    CramIndex=CramIndex,
    Bed=HaplotectBed,
    Name=Name,
    queue=Queue,
    jobGroup=JobGroup
  }

  call make_report {
    input: SVVCF=annotate_svs.vcf,
    GeneVCF=annotate_variants.annotated_filtered_vcf,
    KnownGenes=prepare_bed.genes,
    GeneQC=gene_qc.qc_out,
    SVQC=sv_qc.qc_out,
    Haplotect=run_haplotect.out_file,
    MappingSummary=MappingSummary,
    CoverageSummary=CoverageSummary,
    Name=Name,
    MinReads=MinValidatedReads,
    MinVAF=MinValidatedVAF,
    MinFracCov=MinCovFraction,
    MinGeneCov=MinGeneCov,
    MinRegionCov=MinRegionCov,
    Exception=Exception,
    RefRangeJSON=RefRangeJSON,
    RunInfoString=RunInfoString,
    queue=Queue,
    jobGroup=JobGroup,
    docker=chromoseq_docker,
    tmp=tmp
  }

  call make_report_json {
    input: report=make_report.report,
    Name=Name,
    queue=Queue,
    jobGroup=JobGroup
  }

  call gather_files {
    input: OutputFiles=[annotate_svs.vcf,
    annotate_svs.vcf_index,
    annotate_svs.allvcf,
    annotate_svs.allvcf_index,
    annotate_variants.annotated_filtered_vcf,
    annotate_variants.annotated_filtered_vcf_index,
    annotate_variants.annotated_vcf,
    annotate_variants.annotated_vcf_index,
    run_ichor.params,
    run_ichor.seg,
    run_ichor.allgenomewide_pdf,
    run_ichor.rdata,
    run_ichor.wig,
    gene_qc.qc_out,
    gene_qc.region_dist,
    gene_qc.global_dist,
    sv_qc.qc_out,
    sv_qc.region_dist,
    run_haplotect.out_file],
    OutputKeyFiles=[make_report.report,
    make_report_json.json,
    run_ichor.genomewide_pdf,
    run_ichor.correct_pdf,
    run_haplotect.sites_file],
    OutputDir=OutputDir,
    queue=Queue,
    jobGroup=JobGroup,
    docker=chromoseq_docker
  }

  output {
    String all_done = gather_files.done
  }
}

task prepare_bed {
  String Bedpe
  String Bed
  String Reference
  String queue
  String jobGroup
  String? tmp
  String docker
  
  command <<<
    awk -v OFS="\t" '{ split($7,a,"_"); print $1,$2,$3,a[1],".",$9; print $4,$5,$6,a[2],".",$10; }' ${Bedpe} | sort -u -k 1,1V -k 2,2n > sv.bed
    ((cat sv.bed | cut -f 4) && (cat ${Bed} | cut -f 6)) > genes.txt
    gunzip -c ${Reference} | cut -f 1 > chroms.txt
  >>>

  runtime {
    docker_image: docker
    cpu: "1"
    memory: "4 G"
    queue: queue
    job_group: jobGroup
  }

  output {
    File svbed = "sv.bed"
    File genes = "genes.txt"
    Array[String] chroms = read_lines("chroms.txt")
  }
}

task cov_qc {
  String Cram
  String CramIndex
  String Bed
  String Name
  String refFasta
  String queue
  String jobGroup
  String tmp
  String docker
  
  command <<<
    set -eo pipefail && \
    /opt/conda/bin/mosdepth -n -f ${refFasta} -t 4 -i 2 -x -Q 20 -b ${Bed} --thresholds 10,20,30,40 "${Name}" ${Cram} && \
    /usr/local/bin/bedtools intersect -header -b "${Name}.regions.bed.gz" -a "${Name}.thresholds.bed.gz" -wo | \
    awk -v OFS="\t" '{ if (NR==1){ print $0,"%"$5,"%"$6,"%"$7,"%"$8,"MeanCov"; } else { print $1,$2,$3,$4,$5,$6,$7,$8,sprintf("%.2f\t%.2f\t%.2f\t%.2f",$5/$NF*100,$6/$NF*100,$7/$NF*100,$8/$NF*100),$(NF-1); } }' > "${Name}."$(basename ${Bed} .bed)".covqc.txt" && \
    mv "${Name}.mosdepth.region.dist.txt" "${Name}.mosdepth."$(basename ${Bed} .bed)".region.dist.txt"
  >>>
  
  runtime {
    docker_image: docker
    cpu: "4"
    memory: "32 G"
    queue: queue
    job_group: jobGroup
  }
  
  output {
    File qc_out = glob("*.covqc.txt")[0]
    File global_dist = "${Name}.mosdepth.global.dist.txt"
    File region_dist = glob("*.region.dist.txt")[0]
  }
}

task run_manta {
  String Bam
  String BamIndex 
  String Config
  String Name
  String Reference
  String ReferenceBED
  String queue
  String jobGroup
  String tmp
  String docker
  
  command <<<
    set -eo pipefail && \
    /usr/local/src/manta/bin/configManta.py --config=${Config} --tumorBam=${Bam} --referenceFasta=${Reference} \
    --runDir=manta --callRegions=${ReferenceBED} --outputContig && \
    ./manta/runWorkflow.py -m local -q ${queue} -j 32 -g 32 && \
    zcat ./manta/results/variants/tumorSV.vcf.gz | /bin/sed 's/DUP:TANDEM/DUP/g' > fixed.vcf && \
    /usr/local/bin/duphold_static -v fixed.vcf -b ${Bam} -f ${Reference} -t 4 -o ${Name}.tumorSV.vcf && \
    /opt/conda/bin/bgzip ${Name}.tumorSV.vcf && /usr/bin/tabix -p vcf ${Name}.tumorSV.vcf.gz
  >>>
  runtime {
    docker_image: docker
    cpu: "4"
    memory: "32 G"
    queue: queue
    job_group: jobGroup
  }
  output {
    File vcf = "${Name}.tumorSV.vcf.gz"
    File index = "${Name}.tumorSV.vcf.gz.tbi"
  }
}

task run_ichor {
  String Bam
  String BamIndex
  String ReferenceBED
  String tumorCounts
  String refFasta
  String Name
  String gender
  String genome
  String genomeStyle
  String queue
  String jobGroup
  String gcWig
  String mapWig
  String ponRds
  String centromeres
  
  String? tmp
  String docker
  
  command <<<
    set -eo pipefail && \
    zcat ${tumorCounts} | tail -n +6 | sort -k 1V,1 -k 2n,2 | awk -v window=500000 'BEGIN { chr=""; } { if ($1!=chr){ printf("fixedStep chrom=%s start=1 step=%d span=%d\n",$1,window,window); chr=$1; } print $5; }' > "${Name}.tumor.wig" && \
    /usr/local/bin/Rscript /usr/local/bin/ichorCNA/scripts/runIchorCNA.R --id ${Name} \
    --WIG "${Name}.tumor.wig" --ploidy "c(2)" --normal "c(0.1,0.5,.85)" --maxCN 3 \
    --gcWig ${gcWig} \
    --mapWig ${mapWig} \
    --centromere ${centromeres} \
    --normalPanel ${ponRds} \
    --genomeBuild ${genome} \
    --sex ${gender} \
    --includeHOMD False --chrs "c(1:22, \"X\", \"Y\")" --chrTrain "c(1:22)" --fracReadsInChrYForMale 0.0005 \
    --estimateNormal True --estimatePloidy True --estimateScPrevalence True \
    --txnE 0.999999 --txnStrength 1000000 --genomeStyle ${genomeStyle} --outDir ./ --libdir /usr/local/bin/ichorCNA/ && \
    awk -v G=${gender} '$2!~/Y/ || G=="male"' "${Name}.seg.txt" > "${Name}.segs.txt" && \
    mv ${Name}/*.pdf .
  >>>
  
  runtime {
    docker_image: docker
    cpu: "1"
    memory: "16 G"
    queue: queue
    job_group: jobGroup
  }
  
  output {
    File params = "${Name}.params.txt"
    File seg = "${Name}.segs.txt"
    File genomewide_pdf = "${Name}_genomeWide.pdf"
    File allgenomewide_pdf = "${Name}_genomeWide_all_sols.pdf"
    File correct_pdf = "${Name}_genomeWideCorrection.pdf"
    File rdata = "${Name}.RData"
    File wig = "${Name}.tumor.wig"
  }
}

task run_varscan_snv {
  String Bam
  String BamIndex
  Int? MinCov
  Float? MinFreq
  Int? MinReads
  Float? pvalsnv
  String CoverageBed
  String refFasta
  String Name
  String queue
  String jobGroup
  String? tmp
  String docker
  
  command <<<
    /usr/local/bin/samtools mpileup -f ${refFasta} -l ${CoverageBed} ${Bam} > ${tmp}/mpileup.out && \
    java -Xmx12g -jar /opt/varscan/VarScan.jar mpileup2snp ${tmp}/mpileup.out --min-coverage ${default=6 MinCov} --min-reads2 ${default=3 MinReads} \
    --min-var-freq ${default="0.02" MinFreq} --p-value ${default="0.01" pvalsnv} --output-vcf | /opt/conda/bin/bgzip -c > ${Name}.varscan_snv.vcf.gz && /opt/conda/bin/tabix -p vcf ${Name}.varscan_snv.vcf.gz
  >>>
  
  runtime {
    docker_image: docker
    cpu: "2"
    memory: "16 G"
    queue: queue
    job_group: jobGroup
  }
  output {
    File vcf = "${Name}.varscan_snv.vcf.gz"
  }
}

task run_varscan_indel {
  String Bam
  String BamIndex
  Int? MinCov
  Float? MinFreq
  Int? MinReads
  Float? pvalindel
  String CoverageBed
  String refFasta
  String Name
  String queue
  String jobGroup
  String? tmp
  String docker
  
  command <<<
    /usr/local/bin/samtools mpileup -f ${refFasta} -l ${CoverageBed} ${Bam} > ${tmp}/mpileup.out && \
    java -Xmx12g -jar /opt/varscan/VarScan.jar mpileup2indel ${tmp}/mpileup.out --min-coverage ${default=6 MinCov} --min-reads2 ${default=3 MinReads} \
    --min-var-freq ${default="0.02" MinFreq} --p-value ${default="0.1" pvalindel} --output-vcf | /opt/conda/bin/bgzip -c > ${Name}.varscan_indel.vcf.gz && /opt/conda/bin/tabix -p vcf ${Name}.varscan_indel.vcf.gz
  >>>
  
  runtime {
    docker_image: docker
    cpu: "2"
    memory: "16 G"
    queue: queue
    job_group: jobGroup
  }
  output {
    File vcf = "${Name}.varscan_indel.vcf.gz"
  }
}

task run_pindel_indels {
  String Bam
  String BamIndex
  String Reg
  Int? Isize
  Int? MinReads
  String refFasta
  String Name
  String queue
  String jobGroup
  String tmp
  String genome
  String docker
  
  command <<<
    (set -eo pipefail && /usr/local/bin/samtools view -T ${refFasta} -ML ${Reg} ${Bam} | /opt/pindel-0.2.5b8/sam2pindel - ${tmp}/in.pindel ${default=250 Isize} tumor 0 Illumina-PairEnd) && \
    /usr/local/bin/pindel -f ${refFasta} -p ${tmp}/in.pindel -j ${Reg} -o ${tmp}/out.pindel && \
    /usr/local/bin/pindel2vcf -P ${tmp}/out.pindel -G -r ${refFasta} -e ${default=3 MinReads} -R ${default="hg38" genome} -d ${default="hg38" genome} -v ${tmp}/pindel.vcf && \
    /bin/sed 's/END=[0-9]*\;//' ${tmp}/pindel.vcf | /opt/conda/bin/bgzip -c > ${Name}.pindel.vcf.gz && /opt/conda/bin/tabix -p vcf ${Name}.pindel.vcf.gz
  >>>
  
  runtime {
    docker_image: docker
    cpu: "1"
    memory: "16 G"
    queue: queue
    job_group: jobGroup
  }
  output {
    File vcf = "${Name}.pindel.vcf.gz"
  }
}

task run_manta_indels {
  String Bam
  String BamIndex
  String Reg
  String Config
  String refFasta
  String Name
  String queue
  String jobGroup
  String tmp
  String genome
  String docker
  
  command <<<
    set -eo pipefail && 
    /opt/conda/bin/bgzip -c ${Reg} > ${tmp}/reg.bed.gz && /opt/conda/bin/tabix -p bed ${tmp}/reg.bed.gz && \
    /usr/local/src/manta/bin/configManta.py --config=${Config} --tumorBam=${Bam} --referenceFasta=${refFasta} --runDir=manta --callRegions=${tmp}/reg.bed.gz --outputContig --exome && \
    ./manta/runWorkflow.py -m local -q ${queue} -j 4 -g 32 && \
    /opt/conda/bin/python /usr/local/bin/fixITDs.py -r ${refFasta} ./manta/results/variants/tumorSV.vcf.gz | /opt/conda/bin/bgzip -c > ${Name}.manta.vcf.gz &&
    /opt/conda/bin/tabix -p vcf ${Name}.manta.vcf.gz
  >>>
  
  runtime {
    docker_image: docker
    cpu: "1"
    memory: "16 G"
    queue: queue
    job_group: jobGroup
  }
  output {
    File vcf = "${Name}.manta.vcf.gz"
  }
}

task combine_variants {
  Array[String] VCFs
  String Bam
  String BamIndex
  String refFasta
  String Name
  Int MinReads
  Float MinVAF
  String queue
  String jobGroup
  String? tmp
  String docker

  command {
    /opt/conda/envs/python2/bin/bcftools merge --force-samples -O z ${sep=" " VCFs} | \
    /opt/conda/envs/python2/bin/bcftools norm -d none -f ${refFasta} -O z > ${tmp}/combined.vcf.gz && /usr/bin/tabix -p vcf ${tmp}/combined.vcf.gz && \
    /opt/conda/bin/python /usr/local/bin/addReadCountsToVcfCRAM.py -f -n ${MinReads} -v ${MinVAF} -r ${refFasta} ${tmp}/combined.vcf.gz ${Bam} ${Name} | \
    /opt/conda/bin/bgzip -c > ${Name}.combined_tagged.vcf.gz && /usr/bin/tabix -p vcf ${Name}.combined_tagged.vcf.gz
  }
  runtime {
    docker_image: docker
    cpu: "1"
    memory: "10 G"
    queue: queue
    job_group: jobGroup
  }
  output {
    File combined_vcf_file = "${Name}.combined_tagged.vcf.gz"
  }
}

task annotate_variants {
  String Vcf
  String refFasta
  String Vepcache
  String Cytobands
  String CustomAnnotationVcf
  String CustomAnnotationIndex
  String CustomAnnotationParameters
  String? FilterString
  String Name
  String queue
  String jobGroup
  String? tmp
  String docker
  
  command {
    set -eo pipefail && \
    /usr/bin/perl -I /opt/lib/perl/VEP/Plugins /usr/bin/variant_effect_predictor.pl \
    --format vcf --vcf --fasta ${refFasta} --hgvs --symbol --term SO --per_gene -o ${Name}.annotated.vcf \
    -i ${Vcf} --custom ${Cytobands},cytobands,bed --custom ${CustomAnnotationVcf},${CustomAnnotationParameters} --offline --cache --max_af --dir ${Vepcache} && \
    /opt/htslib/bin/bgzip -c ${Name}.annotated.vcf > ${Name}.annotated.vcf.gz && \
    /usr/bin/tabix -p vcf ${Name}.annotated.vcf.gz && \
    /usr/bin/perl -I /opt/lib/perl/VEP/Plugins /opt/vep/ensembl-vep/filter_vep -i ${Name}.annotated.vcf.gz --format vcf -o ${Name}.annotated_filtered.vcf \
    --filter "${default='MAX_AF < 0.001 or not MAX_AF' FilterString}" && \
    /opt/htslib/bin/bgzip -c ${Name}.annotated_filtered.vcf > ${Name}.annotated_filtered.vcf.gz && \
    /usr/bin/tabix -p vcf ${Name}.annotated_filtered.vcf.gz
  }
  runtime {
    docker_image: docker
    cpu: "1"
    memory: "32 G"
    queue: queue
    job_group: jobGroup
  }
  output {
    File annotated_vcf = "${Name}.annotated.vcf.gz"
    File annotated_vcf_index = "${Name}.annotated.vcf.gz.tbi"
    File annotated_filtered_vcf = "${Name}.annotated_filtered.vcf.gz"
    File annotated_filtered_vcf_index = "${Name}.annotated_filtered.vcf.gz.tbi"
  }
}

task annotate_svs {
  String Vcf
  String CNV
  String refFasta
  String refFastaIndex
  String Vepcache
  String Name
  String gender
  String queue
  String jobGroup
  String SVAnnot
  String Translocations
  String Cytobands
  Int? minCNAsize
  Float? minCNAabund
  
  String? tmp
  String docker
  
  command {
    set -eo pipefail && \
    /usr/bin/perl /usr/local/bin/ichorToVCF.pl -g ${gender} -minsize ${minCNAsize} \
    -minabund ${minCNAabund} -r ${refFasta} ${CNV} | /opt/conda/bin/bgzip -c > cnv.vcf.gz && \
    /opt/htslib/bin/tabix -p vcf cnv.vcf.gz && \
    /opt/conda/envs/python2/bin/bcftools query -l cnv.vcf.gz > name.txt && \
    /usr/bin/perl /usr/local/bin/FilterManta.pl -a ${minCNAabund} -r ${refFasta} -k ${Translocations} ${Vcf} filtered.vcf && \
    /opt/conda/envs/python2/bin/svtools afreq filtered.vcf | \
    /opt/conda/envs/python2/bin/svtools vcftobedpe -i stdin | \
    /opt/conda/envs/python2/bin/svtools varlookup -d 200 -c BLACKLIST -a stdin -b ${SVAnnot} | \
    /opt/conda/envs/python2/bin/svtools bedpetovcf | \
    /usr/local/bin/bedtools sort -header -g ${refFastaIndex} -i stdin | /opt/conda/bin/bgzip -c > filtered.tagged.vcf.gz && \
    /opt/conda/envs/python2/bin/bcftools reheader -s name.txt filtered.tagged.vcf.gz > filtered.tagged.reheader.vcf.gz && \
    /opt/htslib/bin/tabix -p vcf filtered.tagged.reheader.vcf.gz && \
    /opt/conda/envs/python2/bin/bcftools concat -a cnv.vcf.gz filtered.tagged.reheader.vcf.gz | \
    /usr/local/bin/bedtools sort -header -g ${refFastaIndex} -i stdin > svs.vcf && \
    /opt/conda/envs/python2/bin/python /usr/local/src/manta/libexec/convertInversion.py /usr/local/bin/samtools ${refFasta} svs.vcf | /opt/conda/bin/bgzip -c > ${Name}.all_svs.vcf.gz && \
    /opt/htslib/bin/tabix -p vcf ${Name}.all_svs.vcf.gz && \
    /opt/conda/envs/python2/bin/bcftools view -O z -i 'KNOWNSV!="." || (FILTER=="PASS" && (BLACKLIST_AF=="." || BLACKLIST_AF==0)) || LOG2RATIO!="."' ${Name}.all_svs.vcf.gz > svs_filtered.vcf.gz && \
    /opt/htslib/bin/tabix -p vcf svs_filtered.vcf.gz && \
    /usr/bin/perl -I /opt/lib/perl/VEP/Plugins /usr/bin/variant_effect_predictor.pl --format vcf --vcf --fasta ${refFasta} --per_gene --symbol --term SO -o ${Name}.svs_annotated.vcf -i svs_filtered.vcf.gz --custom ${Cytobands},cytobands,bed --offline --cache --dir ${Vepcache} && \
    /opt/htslib/bin/bgzip -c ${Name}.svs_annotated.vcf > ${Name}.svs_annotated.vcf.gz && \
    /opt/htslib/bin/tabix -p vcf ${Name}.svs_annotated.vcf.gz
  }
  
  runtime {
    docker_image: docker
    cpu: "1"
    memory: "24 G"
    queue: queue
    job_group: jobGroup
  }
  
  output {
    File vcf = "${Name}.svs_annotated.vcf.gz"
    File vcf_index = "${Name}.svs_annotated.vcf.gz.tbi"
    File allvcf = "${Name}.all_svs.vcf.gz"
    File allvcf_index = "${Name}.all_svs.vcf.gz.tbi"
  }
}

task run_haplotect {
     String Cram
     String CramIndex
     String Bed
     String Name
     String refDict
     String refFasta
     String queue
     String jobGroup

     Int? MinReads

     command <<<
             /usr/bin/awk -v OFS="\t" '{ $2=$2-1; print; }' ${Bed} > /tmp/pos.bed && \
             /usr/local/openjdk-8/bin/java -Xmx6g \
             -jar /opt/hall-lab/gatk-package-4.1.8.1-18-ge2f02f1-SNAPSHOT-local.jar Haplotect \
             -I ${Cram} -R ${refFasta} --sequence-dictionary ${refDict} \
             -mmq 20 -mbq 20 -max-depth-per-sample 10000 -gstol 0.001 -mr ${default=10 MinReads} \
             -htp ${Bed} -L /tmp/pos.bed -outPrefix ${Name}
     >>>

     runtime {
             docker_image: "registry.gsc.wustl.edu/mgi-cle/haplotect:0.3"
             cpu: "1"
             memory: "8 G"
             queue: queue
             job_group: jobGroup
     }
     output {
            File out_file = "${Name}.haplotect.txt"
            File sites_file = "${Name}.haplotectloci.txt"
     }
}

task make_report {
  String SVVCF
  String GeneVCF
  String KnownGenes
  String MappingSummary
  String? CoverageSummary
  String Haplotect
  String SVQC
  String GeneQC
  String Name
  String Exception
  String RefRangeJSON
  String RunInfoString
  String queue
  String jobGroup
  String tmp
  String docker
  Int? MinReads
  Float? MinVAF
  Int? MinGeneCov
  Int? MinRegionCov
  Int? MinFracCov
  
  command <<<
    cat ${MappingSummary} ${CoverageSummary} | grep SUMMARY | cut -d ',' -f 3,4 | sort -u > qc.txt && \
    /opt/conda/bin/python /usr/local/bin/make_report.py -v ${default="0.05" MinVAF} -r ${default=5 MinReads} -g ${default=30 MinGeneCov} -s ${default=20 MinRegionCov} -f ${default=90 MinFracCov} ${Name} ${GeneVCF} ${SVVCF} ${KnownGenes} "qc.txt" ${GeneQC} ${SVQC} ${Haplotect} "${Exception}" "${RunInfoString}" ${RefRangeJSON} > "${Name}.chromoseq.txt"
  >>>
  
  runtime {
    docker_image: docker
    memory: "8 G"
    queue: queue
    job_group: jobGroup
  }
  
  output {
    File report = "${Name}.chromoseq.txt"
  }
}

task make_report_json {
  String report
  String Name
  String queue
  String jobGroup

  command {
    /usr/local/bin/chromoseq_to_json ${report} > "${Name}.chromoseq.json"
  }
  runtime {
    docker_image: "registry.gsc.wustl.edu/mgi-cle/chromoseq-json:v1"
    memory: "4 G"
    queue: queue
    job_group: jobGroup
  }
  output {
    File json = "${Name}.chromoseq.json"
  }
}

task gather_files {
  Array[String] OutputFiles
  Array[String] OutputKeyFiles
  String OutputDir
  String queue
  String jobGroup
  String docker

  String ChromoseqOutdir = OutputDir + "/chromoseq/"
  
  command {
    if [ ! -d "${OutputDir}" ]; then
      /bin/mkdir ${OutputDir}
    fi

    /bin/mkdir ${ChromoseqOutdir} && \
    /bin/mv -f -t ${ChromoseqOutdir} ${sep=" " OutputFiles} && \
    /bin/mv -f -t ${OutputDir}/ ${sep=" " OutputKeyFiles}
  }
  runtime {
    docker_image: "ubuntu:xenial"
    memory: "4 G"
    queue: queue
    job_group: jobGroup
  }
  output {
    String done = stdout()
  }
}
