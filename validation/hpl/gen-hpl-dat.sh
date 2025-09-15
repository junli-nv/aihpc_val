#!/bin/bash
GMEM_GB=185
NGPUS_PERNODE=4
NTILES=1
#NB=4096
NB=2048
PPN=4

cal(){
  n=$1
  i=$(echo "${n}/sqrt(${n})"|bc)
  while :; do
    if [ $[n % i ] -ne 0 ]; then
      i=$[i-1]
    else
      echo $i
      break
    fi
  done
}

main_hpl(){
  NNODES=$1
  n=$[PPN*NNODES]
  v1=$(cal $n)
  v2=$[n/v1]
  if [ $[v1-v2] -gt 0 ]; then
    P=$v1; Q=$v2
  else
    P=$v2; Q=$v1
  fi
  NTASKS=${n}
#  N=$(echo "(sqrt($NNODES*$NGPUS_PERNODE*$NTILES*(${GMEM_GB}-15)*1024*1024*1024/8)/$NB)*$NB"|bc)
#  N=$(echo "(sqrt($NNODES*$NGPUS_PERNODE*$NTILES*(${GMEM_GB}-25)*1024*1024*1024/8)/$NB)*$NB"|bc)
  N=$(echo "(sqrt($NNODES*$NGPUS_PERNODE*$NTILES*(${GMEM_GB}-30)*1024*1024*1024/8)/$NB)*$NB"|bc)
  cat <<- EOF
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out      output file name (if any)
6            device out (6=stdout,7=stderr,file)
1            # of problems sizes (N)
${N}         Ns
1            # of NBs
${NB}        NBs
1            PMAP process mapping (0=Row-,1=Column-major)
1            # of process grids (P x Q)
${P}         Ps
${Q}         Qs
16.0         threshold
1            # of panel fact
0 1 2        PFACTs (0=left, 1=Crout, 2=Right)
1            # of recursive stopping criterium
2 8          NBMINs (>= 1)
1            # of panels in recursion
2            NDIVs
1            # of recursive panel fact.
0 1 2        RFACTs (0=left, 1=Crout, 2=Right)
1            # of broadcast
3 2          BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
1            # of lookahead depth
1 0          DEPTHs (>=0)
1            SWAP (0=bin-exch,1=long,2=mix)
192          swapping threshold
1            L1 in (0=transposed,1=no-transposed) form
0            U  in (0=transposed,1=no-transposed) form
0            Equilibration (0=no,1=yes)
8            memory alignment in double (> 0)
EOF
}

topdir=/home/cmsupport/workspace/
mkdir -p ${topdir}/hpl/hpldat
for i in 560 # 480 512 #72 #90 #320 400 405 #64 128 256 304 512 #80 #1 2 4 8 16 18 32 36
do
  main_hpl $i > ${topdir}/hpl/hpldat/HPL-GB200-${i}N.dat
done

