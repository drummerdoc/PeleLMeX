#!/bin/bash
set -e
EXE=${EXE:-./PeleLMeX2d.llvm.MPI.ex}
NP=${1:-4}
NS=${NS:-"64 128 256"}
REF=${REF:-512}
run_one() {
  d=$1; n=$2; shift 2
  rm -rf $d
  mkdir $d
  sed "s/^amr.n_cell .*/amr.n_cell = $n $n/" input.wallcorr > $d/input.run
  cd $d
  mpirun -n $NP ../$EXE input.run "$@" > run.log 2>&1
  cd ..
}
for n in $NS; do
  for c in 0 1; do
    run_one run_n${n}_c${c}_cfl07   $n nodal_proj.wall_divu_correction=$c amr.cfl=0.7
    run_one run_n${n}_c${c}_cfl0175 $n nodal_proj.wall_divu_correction=$c amr.cfl=0.175
  done
done
if [ "$REF" != "0" ]; then
  run_one run_n${REF}_c1_cfl07 $REF nodal_proj.wall_divu_correction=1 amr.cfl=0.7
fi
echo done
