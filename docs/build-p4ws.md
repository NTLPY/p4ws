Build P4 Workshop
========================================

This document provides instructions on how to build P4 workshop (P4WS) and install it on your system.

**Contents**
- [Prerequisites](#prerequisites)
- [Build P4WS](#build-p4ws)
- [Install P4WS](#install-p4ws)


Prerequisites
----------------------------------------

Install the required Python packages for building P4WS:
```bash
pip install 'setuptools>=64' 'setuptools_scm>=8'
```


Build P4WS
----------------------------------------

Build python3-p4ws package:
```bash
mkdir -p build && cd build
cmake ..
make
```


Install P4WS
----------------------------------------

Install p4ws-build and p4ws-p4include:
```bash
sudo make install
```

Install python3-p4ws package:
```bash
P4WS_VERSION=`python3 -m setuptools_scm`
pip3 install dist/p4ws-${P4WS_VERSION}-py3-none-any.whl
```
