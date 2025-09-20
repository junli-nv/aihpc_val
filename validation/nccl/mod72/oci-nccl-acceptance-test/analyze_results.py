import matplotlib.pyplot as plt
from optparse import OptionParser
import pandas as pd
import numpy as np

_OPS = ['alltoall', 'all_reduce', 'all_gather', 'reduce_scatter']
_MAX_SIZE = 4 * 1024 * 1024 * 1024 # 4GB

_CONFIG = {
    'ib': {
        'all_gather': {
            'startup_latency': 19.99,
            'bw_eff': 0.95,
            'rtt': 8.56,
        },
        'all_reduce': {
            'startup_latency': 22.33,
            'bw_eff': 0.93,
            'rtt': 18.21,
        },
        'reduce_scatter': {
            'startup_latency': 20.18,
            'bw_eff': 0.95,
            'rtt': 8.52,
        },
        'alltoall': {
            'startup_latency': 22.56,
            'bw_eff': 0.97,
            'rtt': 0.51,
        },
    },
    'roce': {
        'all_gather': {
            'startup_latency': 22.61,
            'bw_eff': 0.86,
            'rtt': 8.91,
        },
        'all_reduce': {
            'startup_latency': 22.30,
            'bw_eff': 0.88,
            'rtt': 19.34,
        },
        'reduce_scatter': {
            'startup_latency': 21.48,
            'bw_eff': 0.87,
            'rtt': 9.13,
        },
        'alltoall': {
            'startup_latency': 22.97,
            'bw_eff': 0.93,
            'rtt': 0.49,
        }
    },
}

class bcolors:
    PASS = '\033[92m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'

def compute_busbw(row):
    op, size, time, nodes = row['op'], row['size'], row['time'], row['nodes']
    if op == 'alltoall':
        coef = 1.0
    elif op == 'all_reduce':
        coef = 2.0 * (nodes - 1) / nodes
    elif op in ['all_gather', 'reduce_scatter']:
        coef = (nodes - 1) / nodes
    else:
        raise AttributeError
    return coef * size / time


def visualize_and_verify(measured_df, reference_df, op, threshold):
    print()
    print(f'Verifying NCCL acceptance for {op}')
    reference_subdf = reference_df[reference_df['op'] == op]
    measured_subdf = measured_df[measured_df['op'] == op].groupby('size').mean('computed_busbw').reset_index()
    # Plot
    _, ax = plt.subplots()
    measured_subdf.plot(x='size', y='computed_busbw', ax=ax, logx=True, label='Measured', title=f'Bandwidth (GB/s) of {op}')
    reference_subdf.plot(x='size', y='computed_busbw', ax=ax, logx=True, label='Reference', title=f'Bandwidth (GB/s) of {op}')
    plt.savefig(f'{op}.png')

    # Verify AUC
    reference_auc = np.trapezoid(reference_subdf['computed_busbw'], reference_subdf['size']) / 1024**4
    measured_auc = np.trapezoid(measured_subdf['computed_busbw'], measured_subdf['size']) / 1024**4
    ratio = measured_auc / reference_auc
    print(f'Measured AUC: {measured_auc:.2f} MB^2/s vs Reference AUC: {reference_auc:.2f} MB^2/s')
    if ratio > threshold:
        print(f'{bcolors.PASS}The AUC difference {ratio:.2f} is higher than the acceptance threshold {threshold:.2f}. Accpetance has passed for {op}.{bcolors.ENDC}')
        return True
    else:
        print(f'{bcolors.FAIL}The AUC difference {ratio:.2f} is lower than the acceptance threshold {threshold:.2f}. Accpetance has failed for {op}.{bcolors.ENDC}')
        print(f'Please check the plot {op}.png')
        return False

def soft_plus(x):
    return np.log(1 + np.exp(x))

def model(network, op, sizes, nodes, max_bw):
    startup_latency = _CONFIG[network][op]['startup_latency']
    bw_eff = _CONFIG[network][op]['bw_eff']
    rtt = _CONFIG[network][op]['rtt']
    
    if op == 'alltoall':
        factor = (nodes - 1) / nodes
        chunk_size = 4 * 1024 * 1024
    elif op == 'all_reduce':
        factor = 2.0 * (nodes - 1) / nodes
        chunk_size = 2 * 1024 * 1024
    elif op in ['all_gather', 'reduce_scatter']:
        factor = (nodes - 1) / nodes
        chunk_size = 2 * 1024 * 1024
    else:
        raise AttributeError
    
    alg_latency = sizes / (bw_eff * max_bw) * factor
    chunck_latency = soft_plus(rtt - (sizes / nodes - chunk_size) / (bw_eff * chunk_size))
    return startup_latency + alg_latency + rtt + (nodes - 2) * chunck_latency

def generate_reference_df(network, maxbw_per_gpu, num_nvl_domains):
    if network not in _CONFIG:
        raise ValueError(f'Network {network} is not supported')
    df = pd.DataFrame()
    size = 1
    while size <= _MAX_SIZE:
        for op in _OPS:
            row = {
                'op': op,
                'size': size,
                'nodes': num_nvl_domains,
                'time': model(network, op, size, num_nvl_domains, maxbw_per_gpu),
            }
            df = pd.concat([df, pd.DataFrame([row])])
        size *= 2
    return df

if __name__ == "__main__":
    parser = OptionParser()
    parser.add_option("-n", "--network", dest="network",
                      help="The network type to be used for the acceptance test, must be 'ib' or 'roce'.")
    parser.add_option("-b", "--maxbw_per_gpu", dest="maxbw_per_gpu", type=float, default=50000.0,
                      help="The maximum bandwidth per GPU in MB/s.")
    parser.add_option("-d", "--num_nvl_domains", dest="num_nvl_domains", type=int,
                      help="The number of NVL domains to be used for the acceptance test.")
    parser.add_option("-m", "--measured", dest="measured",
                      help="The measurement data measured from NCCL test.")
    parser.add_option("-t", "--threshold", dest="threshold", type=float, default=0.95,
                      help="The AUC threshold on whether the acceptance test passes or fails.")
    options, args = parser.parse_args()
    reference_df = generate_reference_df(options.network, options.maxbw_per_gpu, options.num_nvl_domains)
    reference_df['computed_busbw'] = reference_df.apply(compute_busbw, axis=1)
    measured_df = pd.read_pickle(options.measured)
    measured_df['computed_busbw'] = measured_df.apply(compute_busbw, axis=1)
    success = True
    for op in _OPS:
        success &= visualize_and_verify(measured_df, reference_df, op, options.threshold)
    print()
    if success:
        print(f'{bcolors.PASS}Congratulations! The NCCL acceptance test has passed.{bcolors.ENDC}')
    else:
        print(f'{bcolors.FAIL}Unfortunately, the NCCL acceptance test has failed.{bcolors.ENDC}')
