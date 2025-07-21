TNA Externs Tests
========================================


BFSDE Unit Tests
----------------------------------------

```bash
$SDE/run_tofino_model.sh -c ../build/tna_externs/tofino/tna_externs.conf -p tna_externs
$SDE/run_switchd.sh -c ../build/tna_externs/tofino/tna_externs.conf -p tna_externs
$SDE/run_p4_tests.sh -t .
```
