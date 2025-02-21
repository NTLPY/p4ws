"""Tar a program."""

import argparse
import io
import json
import os
import sys
import tarfile

from p4ws.targets.bfsde import bfsde_tar_program, bfsde_untar_program


def make_tar_subparser(parser: argparse._SubParsersAction):
    """Make subparser of tar.

    Parameters
    ----------
    parser : argparse._SubParsersAction
        An ArgumentParser.

    Returns
    -------
    arg_parser : argparse.ArgumentParser
    """

    subparser = parser.add_parser(
        "tar", help="Save program into a single archive.")
    subparser.add_argument("-f", "--file", type=str, required=False,
                           help="use archive file or device ARCHIVE", metavar="ARCHIVE")
    subparser.add_argument("-c", "--create", action="store_true", required=False,
                           help="create a new archive")
    subparser.add_argument("-x", "--extract", "--get", action="store_true", required=False,
                           help="extract files from an archive")
    subparser.add_argument("--bf-conf", type=str, required=False,
                           help="TARGET_CONFIG_FILE that describes P4 artifacts (Generated by bf-p4c*)", metavar="TARGET_CONFIG_FILE")

    subparser.add_argument("-C", "--directory", type=str, required=False,
                           help="change to directory DIR", metavar="DIR")
    return subparser


def main_tar(args: argparse.Namespace):
    """Main of tar executable."""
    if args.directory:
        os.chdir(args.directory)
    if args.create:
        if args.bf_conf:
            tar = bfsde_tar_program(args.file, open(args.bf_conf))
            package_type = "bf-p4c"
        else:
            print(f"Program not specified.", file=sys.stderr)
            return 1

        # Add manifest.json to package
        manifest_json_data = json.dumps(
            {"package-type": package_type}).encode("utf-8")
        tarinfo = tarfile.TarInfo(name="manifest.json")
        tarinfo.size = len(manifest_json_data)
        tar.addfile(tarinfo, io.BytesIO(manifest_json_data))
        tar.close()

    elif args.extract:
        tar = tarfile.open(args.file, "r")

        # Read manifest.json
        manifest = tar.extractfile("manifest.json")
        if manifest is None:
            raise ValueError("Invalid package file: 'manifest.json' not found")

        manifest_json = json.load(manifest)
        if not isinstance(manifest_json, dict) or "package-type" not in manifest_json:
            raise ValueError("Invalid format of manifest.json")
        package_type = manifest_json["package-type"]

        if package_type == "bf-p4c":
            bfsde_untar_program(tar)
        else:
            print(
                f"Unsupported package type: {package_type}", file=sys.stderr)
            return 1
    else:
        print(f"{sys.argv[0]}: Operation not specified.", file=sys.stderr)
        return 1
    return 0
