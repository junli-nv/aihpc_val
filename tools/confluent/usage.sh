#!/bin/bash

## Query GB200 nodes status
docker exec -ti confluent /bin/bash

# GB200-POD1-A[03,05,07,09,11,13,15,17]-Node[01-18]
# GB200-POD1-B[02,04,06,08,10,12,14,16]-Node[01-18]
# GB200-POD2-E[03,05,07,09,11,13,15,17]-Node[01-18]
# GB200-POD2-F[02,04,06,08,10,12,14,16]-Node[01-18]
nodepower GB200-POD1-A03-Node[01-18] status

nodehealth GB200-POD1-A03-Node[01-18]

nodesensors GB200-POD1-A03-Node[01-18] -c fans

nodesensors GB200-POD1-A03-Node[01-18] -c power

nodesensors GB200-POD1-A03-Node[01-18] -c temp

nodeeventlog GB200-POD1-A03-Node[01-18]

nodeboot GB200-POD1-B10-Node09 network

nodeconsole GB200-POD1-B10-Node09 #Quit: ctrl+e -> c -> . 
