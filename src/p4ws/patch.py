"""Patch a SDE."""

import argparse

from p4ws.targets.bfsde import bfsde_patch, get_bfsde_version


def make_patch_subparser(parser: argparse._SubParsersAction):
    """Make subparser of patch.

    Parameters
    ----------
    parser : argparse._SubParsersAction
        An ArgumentParser.

    Returns
    -------
    arg_parser : argparse.ArgumentParser
    """

    subparser = parser.add_parser(
        "patch", help="Patch a SDE.")
    subparser.add_argument("-s", "--name", type=str, required=False,
                           help="name of SDE, can be: 'bfsde'", metavar="SDE")
    return subparser


def main_patch(args: argparse.Namespace):
    """Main of patch executable."""
    patch_bfsde = False
    if args.name is None:
        # Find the SDE automatically
        try:
            get_bfsde_version()
            patch_bfsde = True
            print("-- Barefoot SDE - found")
        except:
            print("-- Barefoot SDE - not found, skipping patching.")

    patch_bfsde = patch_bfsde or args.name.lower() == "bfsde"
    if patch_bfsde:
        print(">>> Patching Barefoot SDE...")
        bfsde_patch()
        print(">>> Barefoot SDE patched successfully.")
