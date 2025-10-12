#!/bin/bash

mkdir -p /tmp/fn_test
cd /tmp/fn_test

cat > view_fn.py <<- 'EOF'
from pathlib import Path
import fiddle as fdl
from nemo_run.core.serialization.zlib_json import ZlibJSONSerializer
import sys

fdl_config_path = sys.argv[1]
fdl_config = Path(fdl_config_path).read_text()
fdl_buildable: fdl.Buildable = ZlibJSONSerializer().deserialize(fdl_config)
print(fdl_buildable)
EOF

#tensorboard = run.Config(
#    TensorBoardLogger,
#    save_dir="nemotron340_tb",
#    name="experiment-512nodes",
#)
#fdl_buildable.log.tensorboard=tensorboard
#fdl_buildable.log.log_dir="/home/cmsupport/workspace/aihpc_val/validation/nemotron4_340b/nemo_run_logs/512nodes"

cat > update_fn_max_steps.py <<- 'EOF'
from pathlib import Path
import fiddle as fdl
from nemo_run.core.serialization.zlib_json import ZlibJSONSerializer
import sys

fdl_config_path=sys.argv[1]
p = Path(fdl_config_path)
fdl_config = p.read_text()
fdl_buildable: fdl.Buildable = ZlibJSONSerializer().deserialize(fdl_config)

fdl_buildable.trainer.max_steps = 1000000
fdl_buildable.trainer.callbacks[2].tp_comm_overlap = False

fdl_buildable_content =  ZlibJSONSerializer().serialize(fdl_buildable)
p.write_text(fdl_buildable_content)
EOF

enroot remove -f nemo
enroot create -n nemo /raid/images/nemo-25.04.rc2.m2.sqsh
enroot list -f

configdir=/home/cmsupport/workspace/aihpc_val/validation/nemotron4_340b/configs/gb200/
fn_script=${configdir}/pretrain_nemotron4_340b_bf16_16nodes_tp4_pp8_cp1_vp12_1mbs_16gbs_fn_or_script

cp $fn_script ${fn_script}.ori

#View max steps
enroot start -w -m /tmp/fn_test:/tmp/fn_test -m ${configdir}:${configdir} nemo \
python /tmp/fn_test/view_fn.py $fn_script | grep max_steps

#Update max steps
enroot start -w -m /tmp/fn_test:/tmp/fn_test -m ${configdir}:${configdir} nemo \
python update_fn_max_steps.py $fn_script

#Check max steps
enroot start -w -m /tmp/fn_test:/tmp/fn_test -m ${configdir}:${configdir} nemo \
python /tmp/fn_test/view_fn.py $fn_script | grep max_steps

enroot remove -f nemo
