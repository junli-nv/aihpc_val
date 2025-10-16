from pathlib import Path
import argparse
from nemo.lightning.pytorch.callbacks import ModelCheckpoint
import fiddle as fdl
from nemo_run.core.serialization.zlib_json import ZlibJSONSerializer
from lightning.pytorch.loggers import TensorBoardLogger
import nemo_run as run
from nemo.lightning.pytorch.callbacks import ModelCheckpoint
from nemo.lightning.resume import AutoResume


def main():
    # Set up command line argument parser
    parser = argparse.ArgumentParser(description='Modify NeMo model Fiddle configuration files')

    # Required argument: input configuration file path
    parser.add_argument('input_config', type=str,
                        help='Path to the input Fiddle configuration file')

    # Optional argument: output configuration file path, defaults to adding .bk to original filename
    parser.add_argument('--output_config', type=str,
                        help='Path to save the modified configuration file, default: input filename.bk')

    # Optional argument: maximum training steps
    parser.add_argument('--max_steps', type=int, default=40000,
                        help='Maximum number of training steps, default: 40000')

    # Optional argument: TensorBoard log save directory
    parser.add_argument('--tb_save_dir', type=str, default="nemotron340_tb",
                        help='TensorBoard log save directory, default: nemotron340_tb')

    # Optional argument: experiment name
    parser.add_argument('--experiment_name', type=str, default="experiment1",
                        help='Experiment name, default: experiment1')

    # Argument: tp_comm_overlap setting
    parser.add_argument('--tp_comm_overlap', type=bool, default=False,
                        help='Whether to enable tensor parallel communication overlap, default: False')

    # Argument: Whether to enable ckpt
    parser.add_argument('--enable-ckpt', type=bool, default=False,
                        help='Whether to enable ckpt, default: False')

    # New argument: log directory path
    parser.add_argument('--log_dir', type=str,
                        default="/nemo_run/code/nemo_experiments",
                        help='Path to the log directory, default: /nemo_run/code/nemo_experiments')

    # Parse arguments
    args = parser.parse_args()

    # Determine output file path
    output_config = args.output_config if args.output_config else f'{args.input_config}.bk'

    try:
        # Read and deserialize configuration file
        config_content = Path(args.input_config).read_text()
        fdl_buildable: fdl.Buildable = ZlibJSONSerializer().deserialize(config_content)

        print("Original configuration:")
        print(fdl_buildable)

        # Create TensorBoard configuration
        tensorboard = run.Config(
            TensorBoardLogger,
            save_dir=args.tb_save_dir,
            name=args.experiment_name,
        )

        # Modify configuration
        fdl_buildable.trainer.max_steps = args.max_steps
        fdl_buildable.trainer.num_nodes = 512
        fdl_buildable.data.global_batch_size = 512
        fdl_buildable.trainer.callbacks[3].data_config.global_batch_size = 512
        fdl_buildable.trainer.callbacks[2].tp_comm_overlap = args.tp_comm_overlap
        fdl_buildable.log.tensorboard = tensorboard
        # Set the log directory from argument
        fdl_buildable.log.log_dir = args.log_dir


        if args.enable_ckpt:
            fdl_buildable.log.ckpt = run.Config(
                ModelCheckpoint,
                save_last=True,
                save_top_k=5,
                every_n_train_steps=1000,
                dirpath='nemo_experiments/default/checkpoints',
                always_save_context=True,
            )
        else:
            fdl_buildable.log.ckpt = None


        print("\nModified configuration:")
        print(fdl_buildable)

        # Serialize and save modified configuration
        modified_content = ZlibJSONSerializer().serialize(fdl_buildable)
        Path(output_config).write_text(modified_content)

        print(f"\nConfiguration successfully saved to: {output_config}")

    except FileNotFoundError:
        print(f"Error: Input file not found {args.input_config}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error processing configuration: {str(e)}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    import sys
    main()
