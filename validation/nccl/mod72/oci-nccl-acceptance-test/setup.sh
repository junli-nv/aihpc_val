#!/bin/bash

## 
apt install -y python3-venv
python -m venv venv
source venv/bin/activate
pip3 install matplotlib pandas
