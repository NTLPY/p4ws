"""Utils for Barefoot SDE."""

import os
from distutils.sysconfig import get_python_lib
from re import match
from subprocess import CalledProcessError, check_output
from typing import Literal

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
