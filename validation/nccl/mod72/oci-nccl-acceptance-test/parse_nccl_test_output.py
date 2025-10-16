import subprocess
from pathlib import Path
import pandas as pd
import re
from dataclasses import dataclass
import os
from optparse import OptionParser

FILENAME_PATTERN = r'LOG_(?P<op>\w+)_perf_N(?P<nodes>\d+)n\d+'

OP_MAP = {
    'AllGather': 'all_gather',
    'ReduceScatter': 'reduce_scatter',
    'AllReduce': 'all_reduce',
    'Reduce': 'reduce',
    'Broadcast': 'broadcast',
}
SPLITMASK_MAP = {
    '1': '0x7',
    '8': '0x0',
}

# uses the last component of current path as the default value for the "topo" field.
DEFAULT_TOPO = os.getcwd().split('/')[-1]
DEFAULT_GPUS_PER_NODE = 8

@dataclass
class Param:
    op: str
    topo: str
    gpus: int
    nodes: int
    proto: str
    algo: str
    splitmask: str

    def calc_busbw_factor(self):
        num = self.gpus * self.nodes
        factor = (num - 1) / num
        if self.op == 'all_reduce':
            factor *= 2
        return factor

    def to_dict(self):
        return {
            'op': self.op,
            'topo': self.topo,
            'gpus': self.gpus,
            'nodes': self.nodes,
            'proto': self.proto,
            'algo': self.algo,
            'splitmask': self.splitmask,
        }

def keys_from_filename(filename):
# Using regex to find matche
    match = re.search(FILENAME_PATTERN, filename)

    if match:
        nodes = int(match.group('nodes'))
        iter = 0
        # iter = match.group('iter')
        splitmask = '0x7'
        # splitmask = match.group('splitmask')
        op = match.group('op')
        algo = 'Ring'
        # algo = match.group('algo')
        maybe_algo = f'_{algo}' if algo else ''
        proto = 'Simple'
        # proto = match.group('proto')
        maybe_proto = f'_{proto}' if proto else ''
        param = Param(
            op=op,
            topo=DEFAULT_TOPO,
            gpus=nodes * DEFAULT_GPUS_PER_NODE,
            nodes=nodes,
            proto=proto,
            algo=algo,
            splitmask=splitmask,
        )
        return f'N{nodes}_{op}_{splitmask}{maybe_algo}{maybe_proto}_{iter}', param
    raise AttributeError(filename)

def dedup_names(names):
    seen = set()
    out_names = []
    for i, name in enumerate(names):
        new_name = name
        idx = 1
        while new_name in seen:
            new_name = f'{new_name}_{idx}'
            idx += 1
        seen.add(new_name)
        out_names.append(new_name)
    return out_names

BYTE_PER_USEC_TO_GBPS = 1000. * 1000. / (1024. * 1024. * 1024.)

def parse_nccl_time_only(lines, params):
    if params is None:
        print('ERROR: Need params for time_only parsing.')
        return None
    size = 8  # I believe its hardcoded
    column_names = ['size', 'time', 'algbw', 'busbw']
    parsed_rows = []
    for line in lines:
        try:
            time = float(line.strip())
        except:
            print(f'ERROR: Cant convert {line.strip()} to float')
            return None
        if time == 0:
            algbw = 0
            busbw = 0
        else:
            # byte/usec -> GB/s : 
            algbw = size / time * BYTE_PER_USEC_TO_GBPS
            busbw = algbw * params.calc_busbw_factor()
        vals = [size, time, algbw, busbw]
        parsed_rows.append(vals)
        size *= 2
    return pd.DataFrame(parsed_rows, columns=column_names)
 

def parse_nccl_test_output(raw_output, params):
    lines = raw_output.strip().split('\n')
    cur_line = 0
    # find column names
    while cur_line < len(lines) and not 'size' in lines[cur_line]:
        cur_line += 1
    if cur_line >= len(lines):
        print(f'WARN: Couldnt find column names. Fallback to timeonly')
        return parse_nccl_time_only(lines, params)
    header_line = lines[cur_line]
    column_names = dedup_names(header_line[1:].split())
    assert cur_line < len(lines), 'header not found'
    cur_line += 2

    parsed_rows = []
    while cur_line < len(lines):
        cols = lines[cur_line].strip().split()
        cur_line += 1
        # sometimes there's a blip 
        if len(cols) != len(column_names):
            continue
        if '#' in cols[0]:
            break
        parsed_cols = []
        for col in cols:
            try:
                col = float(col)
            except ValueError:
                pass
            parsed_cols.append(col)
        parsed_rows.append(parsed_cols)

    return pd.DataFrame(parsed_rows, columns=column_names)
    

def load_nccl_tests(base_path, test_list, suffix=''):
    nccl_test_out = dict()
    for test in test_list:
        path = Path(f'{base_path}/{test}{suffix}')
        try:
            # remove log lines "NCCL {INFO|WARN}"
            # remove empty lines (grep .)
            txt = subprocess.check_output(f'grep -v "NCCL " {path} | grep .', shell=True).decode('utf-8')
        except subprocess.CalledProcessError as err:
            print(f'Skipping file {test} due to error: {err}')
            continue

        keys, params = keys_from_filename(test)
        pandas_df = parse_nccl_test_output(txt, params)
        if pandas_df is not None:
            for key, val in params.to_dict().items():
                pandas_df[key] = val
            print('added pandas df: ', params.to_dict(), pandas_df.shape)
        else:
            print(f'WARN: could not parse {path}')
        nccl_test_out[keys] = pandas_df
    return nccl_test_out


def merge_dataset_dict(df_dict):
    """ Creates one dataset out of a dict of datasets. """
    return pd.concat(df_dict.values(), axis=0)


if __name__ == '__main__':
    parser = OptionParser()
    parser.add_option("-m", "--merge",
                  action="store_true", dest="merge", default=False,
                  help="don't print status messages to stdout")
    options, args = parser.parse_args()

    import os
    all_files = subprocess.check_output('find . -name LOG_*', shell=True).decode('utf-8').strip().split('\n')
    BASE_PATH = os.getcwd()

    loaded_tests = load_nccl_tests(BASE_PATH, all_files)

    filename = 'data.pkl' if not options.merge else 'data_full.pkl'
    if options.merge:
        loaded_tests = merge_dataset_dict(loaded_tests)
        print(loaded_tests.algo.unique())
        print(f'Merging all datasets into one, saving to {filename}')


    import pickle
    with open(f'{BASE_PATH}/{filename}', 'wb') as f:
        pickle.dump(loaded_tests, f)
