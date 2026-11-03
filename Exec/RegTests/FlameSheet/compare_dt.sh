#!/bin/bash
set -e
BASE=$1
BRANCH=$2
NP=${3:-32}
FCOMPARE=${FCOMPARE:-../../../Submodules/PelePhysics/Submodules/amrex/Tools/Plotfile/fcompare.gnu.ex}
for exe in base branch; do
  for dt in dt1 dt2 dt3; do
    d=run_${exe}_${dt}
    rm -rf $d
    mkdir $d
    cd $d
    if [ $exe = base ]; then E=../$BASE; else E=../$BRANCH; fi
    mpirun -n $NP $E ../input.dtcompare_${dt} > run.log 2>&1
    cd ..
  done
done
{
echo "=== branch vs base, dt = 1e-5"
$FCOMPARE run_base_dt1/plt00020 run_branch_dt1/plt00020 || true
echo "=== branch vs base, dt = 5e-6"
$FCOMPARE run_base_dt2/plt00040 run_branch_dt2/plt00040 || true
echo "=== base: dt=1e-5 vs dt=5e-6"
$FCOMPARE run_base_dt1/plt00020 run_base_dt2/plt00040 || true
echo "=== base: dt=5e-6 vs dt=2.5e-6"
$FCOMPARE run_base_dt2/plt00040 run_base_dt3/plt00080 || true
echo "=== branch: dt=1e-5 vs dt=5e-6"
$FCOMPARE run_branch_dt1/plt00020 run_branch_dt2/plt00040 || true
echo "=== branch: dt=5e-6 vs dt=2.5e-6"
$FCOMPARE run_branch_dt2/plt00040 run_branch_dt3/plt00080 || true
} > compare_dt.out 2>&1
echo done
