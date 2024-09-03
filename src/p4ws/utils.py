"""Utils."""

import importlib


def get_type(path: str):
    """Get type by its type name.

    Get a type object by its full type name, including module name and class name:
    - `mininet.node.Host`
    - `mininet.node.Switch`

    Args:
        path: Full type name, including module name and class name or None.

    Returns:
        A type, or None if path is None.

    Raises:
        ModuleNotFoundError: Path contain a module not found.
        AttributeError: Type not found in specified module.
        ValueError: Path is not name of a type.
    """

    if not path:
        return None
    r = path.rsplit(".", 1)
    if len(r) != 1:
        mod, cls = r
        t = getattr(importlib.import_module(mod), cls)
    else:
        try:
            t = eval(path)
        except Exception as e:
            raise ValueError(f"{path} is not name of a type")
    if not isinstance(t, type):
        raise ValueError(f"{path} is not name of a type")
    return t


def get_type_name(obj: object):
    """Get type name of an object."""
    return type(obj).__name__
