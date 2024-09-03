"""Errors."""


class ParserError(ValueError):
    """Error raised when format of file is incorrect."""

    def __init__(self, msg):
        ValueError.__init__(self, msg)
        self.msg = msg

    def __reduce__(self):
        return self.__class__, (self.msg)
