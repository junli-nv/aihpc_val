#!/bin/bash
#
simple_aly(){
echo reduce_scatter_perf
for i in $(ls -1rth *Rack*.txt); do
  printf "%100s%10s\n" $i $(cat $i|awk '/INFO: reduce_scatter_perf BEGIN/,/INFO: reduce_scatter_perf DONE/{print $0}'|grep 'float.*sum'|awk '{print $8}'|sort -n|tail -n1)
done
echo all_reduce_perf
for i in $(ls -1rth *Rack*.txt); do
  printf "%100s%10s\n" $i $(cat $i|awk '/INFO: all_reduce_perf BEGIN/,/INFO: all_reduce_perf DONE/{print $0}'|grep 'float.*sum'|awk '{print $8}'|sort -n|tail -n1)
done
echo all_gather_perf
for i in $(ls -1rth *Rack*.txt); do
  printf "%100s%10s\n" $i $(cat $i|awk '/INFO: all_gather_perf BEGIN/,/INFO: all_gather_perf DONE/{print $0}'|grep 'float.*none'|awk '{print $8}'|sort -n|tail -n1)
done
echo alltoall_perf
for i in $(ls -1rth *Rack*.txt); do
  printf "%100s%10s\n" $i $(cat $i|awk '/INFO: alltoall_perf BEGIN/,/INFO: alltoall_perf DONE/{print $0}'|grep 'uint8.*none'|awk '{print $8}'|sort -n|tail -n1)
done
}

cd results
for i in $(ls -1rth *Rack*.txt); do
   for cmd in reduce_scatter_perf all_reduce_perf all_gather_perf alltoall_perf; do
   cat $i|awk "/INFO: ${cmd} BEGIN/,/INFO: ${cmd} DONE/{print \$0}" \
     &> LOG_${cmd}_N$(echo $i|awk -F'-' '{print $(NF-1)}'|tr -d 'N')n4.txt
   done
done
rm -rf ../oci-nccl-acceptance-test/logs/
mkdir -p ../oci-nccl-acceptance-test/logs
cp -v LOG_*N576n4.txt ../oci-nccl-acceptance-test/logs/
cd ../oci-nccl-acceptance-test/
rm -f *.png data_full.pkl
source venv/bin/activate
python parse_nccl_test_output.py -m
python analyze_results.py -m data_full.pkl -n ib -d 32 -b 50000.0 -t 0.95
mv *.png data_full.pkl logs/
