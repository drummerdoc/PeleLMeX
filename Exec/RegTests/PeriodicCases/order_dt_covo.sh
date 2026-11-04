#!/bin/bash
set -e
NP=${1:-8}
EXE=${EXE:-./PeleLMeX2d.gnu.MPI.ex}
FCOMPARE=${FCOMPARE:-../../../Submodules/PelePhysics/Submodules/amrex/Tools/Plotfile/fcompare.gnu.ex}
DTS="4.0e-5 2.0e-5 1.0e-5 5.0e-6"
T=0.02
for pass in inv2 inv1 visc2; do
  case $pass in
    inv2)  extra="peleLM.sdc_iterMax=2";;
    inv1)  extra="peleLM.sdc_iterMax=1";;
    visc2) extra="peleLM.sdc_iterMax=2 transport.const_viscosity=0.02";;
  esac
  k=0
  for dt in $DTS; do
    k=$((k+1))
    d=run_${pass}_dt$k
    rm -rf $d
    mkdir $d
    cd $d
    mpirun -n $NP ../$EXE ../input.covo_dtorder amr.fixed_dt=$dt amr.stop_time=$T $extra > run.log 2>&1
    cd ..
  done
done
last() { ls -d $1/plt* | grep -v plt00000 | tail -1; }
{
for pass in inv2 inv1 visc2; do
  echo "=== $pass: error vs exact (final vs initial), dt = 4e-5, 2e-5, 1e-5, 5e-6"
  for k in 1 2 3 4; do
    echo "--- run_${pass}_dt$k"
    $FCOMPARE run_${pass}_dt$k/plt00000 $(last run_${pass}_dt$k) | grep "x_velocity\|y_velocity\|density\|temp " || true
  done
  echo "=== $pass: Richardson pairs"
  for k in 1 2 3; do
    echo "--- dt$k vs dt$((k+1))"
    $FCOMPARE $(last run_${pass}_dt$k) $(last run_${pass}_dt$((k+1))) | grep "x_velocity\|y_velocity\|density\|temp " || true
  done
done
} > order_dt_covo.out 2>&1
echo done
