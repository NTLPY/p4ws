"""Utils for Barefoot SDE."""

import io
import json
import os
import tarfile
from distutils.sysconfig import get_python_lib
from re import match
from subprocess import CalledProcessError, check_output
from typing import Literal, TextIO

BFSDE = ""
BFSDE_INSTALL = ""


def get_bfsde():
    """Get path to Barefoot SDE.

    Check envs below to check path to Barefoot SDE:
    1. `BFSDE`
    2. `SDE`

    Returns:
        A str of path to Barefoot SDE.

    Raises:
        FileNotFoundError: Barefoot SDE not found.
    """

    global BFSDE
    if BFSDE == "":
        BFSDE = os.environ.get("BFSDE", "")
    if BFSDE == "":
        BFSDE = os.environ.get("SDE", "")
    if BFSDE == "":
        raise FileNotFoundError("Barefoot SDE not found")

    return BFSDE


def get_bfsde_install(*suffix: str):
    """Get path to install path of Barefoot SDE.

    Check envs below to check install path to Barefoot SDE:
    1. `BFSDE_INSTALL`
    2. `SDE_INSTALL`

    Returns:
        A str of install path to Barefoot SDE.

    Raises:
        FileNotFoundError: Install path of Barefoot SDE not found.
    """

    global BFSDE_INSTALL
    if BFSDE_INSTALL == "":
        BFSDE_INSTALL = os.environ.get("BFSDE_INSTALL", "")
    if BFSDE_INSTALL == "":
        BFSDE_INSTALL = os.environ.get("SDE_INSTALL", "")
    if BFSDE_INSTALL == "":
        raise FileNotFoundError("Install path of Barefoot SDE not found")

    return os.path.join(BFSDE_INSTALL, *suffix)


def get_bfsde_ld_library_path():
    """Get appropriate `LD_LIBRARY_PATH`.

    Returns:
        A str of `LD_LIBRARY_PATH`.

    Raises:
        FileNotFoundError: Install path of Barefoot SDE not found.
    """

    bfsde_lib = get_bfsde_install("lib")
    return f"/usr/local/lib:{bfsde_lib}"


def get_bfsde_tofino_model():
    """Get `tofino-model`.

    Get `LD_LIBRARY_PATH`, path to, version, internal version and commit of `tofino-model`.

    `CAP_NET_RAW` privilege is required.

    Returns:
        A tuple of str include `LD_LIBRARY_PATH`, path to, version, internal version and commit of `tofino-model`.

    Raises:
        CalledProcessError: Maybe library not found or priviledge required.
        UnicodeDecodeError: Output of `tofino-model` cannot be decoded as utf-8.
        FileNotFoundError: Install path of Barefoot SDE or `tofino-model` not found.
        PermissionError: Execution priviledge required.
        OSError: Maybe file of `tofino-model` is corrupted and cannot be executed.
        RuntimeError: Output of `tofino-model` is unexpected.
    """

    ld_path = get_bfsde_ld_library_path()
    tofino_model = get_bfsde_install("bin", "tofino-model")

    try:
        out = check_output([tofino_model, "--iversion"],
                           env={"LD_LIBRARY_PATH": ld_path})
        out_str = out.decode("utf-8")
    except CalledProcessError as e:
        # Library / sudo
        raise e
    except UnicodeDecodeError as e:
        # Unexpected output
        raise e
    except FileNotFoundError as e:
        raise e
    except PermissionError as e:
        raise e
    except OSError as e:
        # Unexpected file
        raise e

    for line in out_str.split('\n'):
        m = match(
            r"tofino-model ([0-9]+.[0-9]+.[0-9]+)--\(([0-9]+.[0-9]+.[0-9]+)-([0-9a-z]{40})\)", line)
        if m is not None:
            ver, iver, commit = m.groups()
            return ld_path, tofino_model, ver, iver, commit

    # Unexpected output
    raise RuntimeError(f"Unexpected output of tofino-model: {out_str}")


def get_bfsde_python_path():
    """Get python path of SDE.

    Returns:
        path(str): Path to python site-packages of SDE.

    Raises:
        FileNotFoundError: Install path of Barefoot SDE not found.

    References:
        - ${SDE}/run_p4_tests.sh
    """
    python_lib = get_python_lib(
        prefix='', standard_lib=True, plat_specific=True)
    return get_bfsde_install(python_lib, "site-packages")


def get_bfsde_python_path_for_p4_test(arch: Literal["", "tofino", "tofino2", "tofino2m", "tofino3"] = ""):
    """Get python path of SDE for p4 tests.

    Args:
        arch(str): Architecture of target program, use to retrieve generated PD files inside SDE,
        could be "tofino", "tofino2", "tofino2m", "tofino3", or ""(default) indicating no PD inside SDE is needed.

    Returns:
        paths(list[str]): Python paths.

    Raises:
        FileNotFoundError: Install path of Barefoot SDE not found.

    References:
        - ${SDE}/run_p4_tests.sh
    """

    bfsde_python_path = get_bfsde_python_path()
    python_paths = []
    python_paths.append(os.path.join(bfsde_python_path, "tofino/bfrt_grpc"))
    python_paths.append(bfsde_python_path)
    python_paths.append(os.path.join(bfsde_python_path, "tofino"))
    if arch:
        python_paths.append(os.path.join(bfsde_python_path, f"{arch}pd"))
    python_paths.append(os.path.join(bfsde_python_path, "p4testutils"))
    return python_paths


def bfsde_filter_target_config(obj: dict, conf_path: str, relative: bool = True):
    """Translate path of program files or artifacts in configuration into relative path or abspath.

    Parameters
    ----------
    obj : dict
        Configuration object.
    conf_path : str
        Path to this configuration file.
    relative : bool
        Wanted path type.

    Returns
    -------
    files : list[str]
        Path to files that the program contains.
    dirs : list[str]
        Path to directories that the program contains.

    Raises
    ------
    ValueError
        Format of obj is incorrect.
    """

    files = []
    dirs = []

    def swap(path: str, isdir=False):
        if not isinstance(path, str):
            raise ValueError("Path should be a str")

        if os.path.isabs(path):
            abspath = path
        else:
            abspath = os.path.abspath(os.path.join(
                os.path.dirname(conf_path), path))

        if not isdir:
            files.append(abspath)
        else:
            dirs.append(abspath)

        return os.path.relpath(path, os.path.dirname(conf_path)) if relative else abspath

    p4_devices = obj.get("p4_devices", [])
    if not isinstance(p4_devices, list):
        raise ValueError("['p4_devices'] should be a list")

    for p4_device in p4_devices:
        if not isinstance(p4_device, dict):
            raise ValueError("['p4_devices'][*] should be a dict")

        p4_programs = p4_device.get("p4_programs", [])
        if not isinstance(p4_programs, list):
            raise ValueError(
                "['p4_devices'][*]['p4_programs'] should be a list")

        for p4_program in p4_programs:
            if not isinstance(p4_program, dict):
                raise ValueError(
                    "['p4_devices'][*]['p4_programs'][*] should be a dict")

            p4_program["bfrt-config"] = swap(p4_program["bfrt-config"])

            p4_pipelines = p4_program.get("p4_pipelines", [])
            if not isinstance(p4_pipelines, list):
                raise ValueError(
                    "['p4_devices'][*]['p4_programs'][*]['p4_pipelines'] should be a list")

            for p4_pipeline in p4_pipelines:
                if not isinstance(p4_pipeline, dict):
                    raise ValueError(
                        "['p4_devices'][*]['p4_programs'][*]['p4_pipelines'][*] should be a dict")

                p4_pipeline["context"] = swap(p4_pipeline["context"])
                p4_pipeline["config"] = swap(p4_pipeline["config"])
                p4_pipeline["path"] = swap(p4_pipeline["path"], isdir=True)

    return files, dirs


def bfsde_tar_program(file: str, conf: TextIO):
    """Tar a program generated by bf-p4c.

    Parameters
    ----------
    file : str
        Path to target tar file.
    conf : TextIO
        Configuration file.

    Returns
    -------
    tar : tarfile.TarFile
        Generated package file.

    Raises
    ------
    ValueError, json.JSONDecodeError
        Format of configuration is incorrect.
    """

    obj = json.load(conf)
    _, dirs = bfsde_filter_target_config(obj, ".", True)

    def filter_conf(tarinfo: tarfile.TarInfo):
        if os.path.samefile(tarinfo.name, conf.name):
            return None
        return tarinfo

    tar = tarfile.open(file, 'w')
    for d in dirs:
        relpath = os.path.relpath(d, os.getcwd())
        tar.add(relpath, filter=filter_conf)

    # Add program.conf
    conf_data = json.dumps(obj).encode("utf-8")
    tarinfo = tarfile.TarInfo(name="program.conf")
    tarinfo.size = len(conf_data)
    tar.addfile(tarinfo, io.BytesIO(conf_data))
    return tar


def bfsde_untar_program(tar: tarfile.TarFile):
    """Untar a program generated by bf-p4c.

    Parameters
    ----------
    tar : tarfile.TarFile
        Package file.

    Raises
    ------
    ValueError, json.JSONDecodeError
        Format of package is incorrect.
    """

    # Read program.conf
    conf_file = tar.extractfile("program.conf")
    if conf_file is None:
        raise ValueError(
            "Invalid bf-p4c package file: 'program.conf' not found")
    obj = json.load(conf_file)
    bfsde_filter_target_config(obj, ".", False)
    with open("program.conf", "w") as f:
        json.dump(obj, f)

    def filter_conf(member: tarfile.TarInfo, dest_path: str):
        if member.name == "program.conf":
            return None
        return member

    tar.extractall(filter=filter_conf)
