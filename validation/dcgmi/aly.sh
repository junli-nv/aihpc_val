#!/bin/bash
#
if [ $# -lt 1 ]; then
  echo "Usage: $(basename $0) logdir"
  exit 0
fi
logdir=$1
cd $logdir

echo Deployment
for i in *.txt; do
echo $logdir/$i $(cat $i|grep -Ev 'INFO|^\+'|jq '."DCGM Diagnostic".test_categories[]|select (.category=="Deployment")'|jq '.tests[].test_summary.status')
done|grep -i Fail

echo Hardware
for i in *.txt; do
echo $logdir/$i $(cat $i|grep -Ev 'INFO|^\+'|jq '."DCGM Diagnostic".test_categories[]|select (.category=="Hardware")'|jq '.tests[].test_summary.status')
done|grep -i Fail

echo Stress
for i in *.txt; do
echo $logdir/$i $(cat $i|grep -Ev 'INFO|^\+'|jq '."DCGM Diagnostic".test_categories[]|select (.category=="Stress")'|jq '.tests[].test_summary.status')
done|grep -i Fail

echo Integration
for i in *.txt; do
echo $logdir/$i $(cat $i|grep -Ev 'INFO|^\+'|jq '."DCGM Diagnostic".test_categories[]|select (.category=="Integration")'|jq '.tests[].test_summary.status')
done|grep -i Fail
