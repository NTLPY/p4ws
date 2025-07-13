"""Main of P4 Workshop executable."""

import argparse
import sys

from . import __version__
from .loadmn import *
from .patch import *
from .tar import *


def main(args: argparse.Namespace):
    """Main of P4 Workshop executable."""
    if args.subparser_name == "loadmn":
        return main_loadmn(args)
    elif args.subparser_name == "patch":
        return main_patch(args)
    elif args.subparser_name == "tar":
        return main_tar(args)
    else:
        print(f"Unknown command: {args.subparser_name}.", file=sys.stderr)
        parser.print_help()
        return 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        prog="python3 -m p4ws",
        description=__doc__)

    subparsers = parser.add_subparsers(dest="subparser_name")
    make_loadmn_subparser(subparsers)
    make_patch_subparser(subparsers)
    make_tar_subparser(subparsers)
    subparsers.add_parser("help", help="Show this help message and exit.")
    subparsers.add_parser("version", help="Show version and exit.")

    args = parser.parse_args()
    if args.subparser_name == "help":
        parser.print_help()
        exit(0)
    elif args.subparser_name == "version":
        print(f"P4 Workshop")
        print(f"Version {__version__}")
        exit(0)
    elif args.subparser_name is None:
        parser.print_help(sys.stderr)
        exit(1)

    exit(main(args))
