# load Intel compilers and mkl
source /theoryfs2/common/software/intel2015/bin/compilervars.sh intel64
# force static link to Intel mkl, except for openmp
MKLROOT=/theoryfs2/common/software/intel2015/composer_xe_2015.0.090/mkl/lib/intel64
#LAPACK_INTERJECT="${MKLROOT}/libmkl_intel_lp64.a ${MKLROOT}/libmkl_intel_thread.a ${MKLROOT}/libmkl_core.a -liomp5 -lm"
## link against older libc for generic linux
#TLIBC=/theoryfs2/ds/cdsgroup/psi4-compile/psi4cmake/psi4/glibc2.12rpm
#LIBC_INTERJECT="-L${TLIBC}/usr/lib64 ${TLIBC}/lib64/libpthread.so.0 ${TLIBC}/lib64/libc.so.6"
## round off with pre-detected dependencies
#MCONDA=/theoryfs2/ds/cdsgroup/psi4-install/miniconda/envs/gslenv/lib
#GSL_INTERJECT="-L${MCONDA};-lhdf5;-lhdf5_hl;-lhdf5;-lpthread;-lz;-lrt;-ldl;-lm"
#HDF5_INTERJECT="-L${MCONDA};-lgsl;-lgslcblas;-lm"
# redistribute the Intel openmp
REDIST=${MKLROOT}/../../../compiler/lib/intel64/libiomp5.so

# make (in subdir so plugin gets correct name)
mkdir csx4psi
cd csx4psi
cp -p ../csx4psi.cc .
psi4 --new-plugin-makefile
make
mv csx4psi.so ..
cd ..
# install
mkdir -p ${PREFIX}/lib
cp ${REDIST} ${PREFIX}/lib/
mkdir -p ${PREFIX}/psi4aux/csx4psi
cp README.md ${PREFIX}/psi4aux/csx4psi/
cp __init__.py ${PREFIX}/psi4aux/csx4psi/
cp pymodule.py ${PREFIX}/psi4aux/csx4psi/
cp csx1_api.py ${PREFIX}/psi4aux/csx4psi/
cp csx4psi.cc ${PREFIX}/psi4aux/csx4psi/
cp csx4psi.so ${PREFIX}/psi4aux/csx4psi/

