#!/bin/bash
set -e
BASE=$1
BRANCH=$2
NP=${3:-32}
FCOMPARE=${FCOMPARE:-../../../Submodules/PelePhysics/Submodules/amrex/Tools/Plotfile/fcompare.gnu.ex}
rm -rf ref_run
mkdir ref_run
cd ref_run
mpirun -n $NP ../$BRANCH ../input.order_ref > run.log 2>&1
cd ..
CHK=$(ls -d ref_run/chk* | tail -1)
N0=$(basename $CHK | sed 's/[^0-9]//g')
N0=$((10#$N0))
echo "reference checkpoint $CHK at step $N0"
for exe in base branch; do
  if [ $exe = base ]; then E=../$BASE; else E=../$BRANCH; fi
  for i in 1 2 3; do
    case $i in
      1) dt=1.0e-5; ns=20;;
      2) dt=5.0e-6; ns=40;;
      3) dt=2.5e-6; ns=80;;
    esac
    d=order_${exe}_dt$i
    rm -rf $d
    mkdir $d
    cd $d
    mpirun -n $NP $E ../input.order_restart amr.restart=../$CHK amr.fixed_dt=$dt amr.max_step=$((N0+ns)) > run.log 2>&1
    cd ..
  done
done
last() { ls -d $1/plt* | tail -1; }
{
echo "=== base: dt=1e-5 vs dt=5e-6"
$FCOMPARE $(last order_base_dt1) $(last order_base_dt2) || true
echo "=== base: dt=5e-6 vs dt=2.5e-6"
$FCOMPARE $(last order_base_dt2) $(last order_base_dt3) || true
echo "=== branch: dt=1e-5 vs dt=5e-6"
$FCOMPARE $(last order_branch_dt1) $(last order_branch_dt2) || true
echo "=== branch: dt=5e-6 vs dt=2.5e-6"
$FCOMPARE $(last order_branch_dt2) $(last order_branch_dt3) || true
} > order_restart.out 2>&1
echo done
