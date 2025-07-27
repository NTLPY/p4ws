Transfer P4 Program
========================================

This document provides instructions on how to transfer your P4 program to other location or even other host.

**Contents**
- [Prerequisites](#prerequisites)
- [Pack your P4 Program](#pack-your-p4-program)
- [Unpack your P4 Program](#unpack-your-p4-program)


Prerequisites
----------------------------------------

- [Build P4 Program](./build-p4-program.md)


Pack your P4 Program
----------------------------------------

- Navigate to build directory.

  ```bash
  cd build
  ```

- Pack your P4 program into a tarball.

  ```bash
  # For tofino targets
  python3 -m p4ws tar -cf TARBALL_NAME.tar --bf-conf P4_NAME/TARGET/P4_SRC_NAME.conf
  ```


Unpack your P4 Program
----------------------------------------

- Unpack the tarball on the target host.

  ```bash
  make -p P4_NAME && cd P4_NAME # Create the directory to store the P4 program
  python3 -m p4ws tar -xf TARBALL_NAME.tar
  ```
