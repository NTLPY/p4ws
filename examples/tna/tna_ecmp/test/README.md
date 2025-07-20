TNA ECMP Tests
========================================


BFSDE Unit Tests
----------------------------------------

```bash
$SDE/run_tofino_model.sh -c ../build/tna_ecmp/tofino/tna_ecmp.conf -p tna_ecmp
$SDE/run_switchd.sh -c ../build/tna_ecmp/tofino/tna_ecmp.conf -p tna_ecmp
$SDE/run_p4_tests.sh -t .
```
