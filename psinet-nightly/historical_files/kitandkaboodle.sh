#!/bin/bash

# [LAB, 28 Jun 2016]
# execute as >>> bash -x -e kitandkaboodle.sh args

#
# This is obsolete, not used anymore... check kitandkapoodle.py
# CDS 2/1/18
#

if [ $# -ne 1 ]; then
    echo $0: usage: kitandkaboodle.sh stage1     # setup from scratch
    echo $0: usage: kitandkaboodle.sh stage12    # setup from scratch and build all
    echo $0: usage: kitandkaboodle.sh stage2psi  # build psi4 only
    echo $0: usage: kitandkaboodle.sh stage3     # package up installer
    exit 1
fi
stage=$1

#############
#   PREP    #
#############

# MINIINSTALLER file is only thing in MINIBUILDDIR

if [ "$(uname)" == "Darwin" ]; then
    unset PYTHONHOME PYTHONPATH DYLD_LIBRARY_PATH PSIDATADIR
    export PATH=/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/texbin

    PLATFORM=osx-64
    PLATFORM2=MacOSX

    MINIBUILDDIR=/Users/loriab/linux/psi4-build
    MINIINSTALLER=Miniconda-latest-MacOSX-x86_64.sh
    NIGHTLYDIR=/Users/loriab/linux/psi4meta/conda-recipes
    #CONDA_BLD_PATH none b/c no hard drive difference on laptop
fi

if [ "$(uname)" == "Linux" ]; then
    export PATH=/theoryfs2/common/software/libexec/git-core:/theoryfs2/ds/cdsgroup/perl5/bin:/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin

    PLATFORM=linux-64
    PLATFORM2=Linux

    MINIBUILDDIR=/theoryfs2/ds/cdsgroup/psi4-build
    MINIINSTALLER=Miniconda-latest-Linux-x86_64.sh
    NIGHTLYDIR=/theoryfs2/ds/cdsgroup/psi4-compile/psi4meta/conda-recipes
    export CONDA_BLD_PATH=/scratch/cdsgroup/conda-builds
fi

VERSION=1.0.0
CHANNEL="localchannel-$VERSION"
VERSION3=1.0.0


#############
#  STAGE 1  #
#############

# * set VERSION above
# * clear PIN-TO-BUILD in recipes
# * prepare items in $NIGHTLYDIR/installer/construct.yaml
#   - increment and match above VERSION in "version"
#   - free only in "channels"
#   - uncomment build/run
#   - true "keep_pkgs"
#   - comment "post_install"

if [[ $stage == "stage1" || $stage == "stage12" ]]; then

# <<<  Prepare Throwaway Conda Installation w/ Driver  >>>

cd $MINIBUILDDIR
bash $MINIINSTALLER -b -p $MINIBUILDDIR/minicondadrive
export PATH=$MINIBUILDDIR/minicondadrive/bin:$PATH
conda update --yes --all
    # install packages from installer/construct.yaml "driver" section
conda install --yes conda conda-build constructor anaconda-client
conda list

# <<<  Run Constructor of Build/Run  >>>

conda install --yes conda=4.0.9 constructor=1.2.0

cd $NIGHTLYDIR
constructor installer
bash psi4conda-$VERSION-$PLATFORM2-x86_64.sh -b -p $MINIBUILDDIR/minicondastore-$VERSION
cd $MINIBUILDDIR
mkdir -p "$CHANNEL/$PLATFORM"
cd "$CHANNEL/$PLATFORM"
ln -s $MINIBUILDDIR/minicondastore-$VERSION/pkgs/*bz2 .
conda index

fi

#############
#  STAGE 2  #
#############

# * check VERSION above is the pkg repo want recipes built from
# * set PIN-TO-BUILD in recipes (e.g., hdf5 and chemps2) to detected one from stage 1
# * installer/construct.yaml irrelevant
# * leave the ordering, but can choose the built packages
# * increment recipe build numbers if want to upload

if [[ $stage == "stage2" || $stage == "stage12" ]]; then

# <<<  Prep  >>>

export PATH=$MINIBUILDDIR/minicondadrive/bin:$PATH

# <<<  Run Conda-Build on QC Set  >>>

conda install --yes conda conda-build
conda list

cd $NIGHTLYDIR
conda build --override-channels \
    -c file://$MINIBUILDDIR/$CHANNEL \
    dftd3 \
    pcmsolver \
    chemps2 pychemps2 \
    psi4 \
    v2rdm_casscf

fi

################
#  STAGE 2PSI  #
################

if [ $stage == "stage2psi" ]; then

# <<<  Prep  >>>

export PATH=$MINIBUILDDIR/minicondadrive/bin:$PATH
CONDABUILDDIR=$CONDA_BLD_PATH/work/build

# <<<  Run Conda-Build on QC Set  >>>

conda install --yes conda conda-build
conda list

cd $NIGHTLYDIR
conda build --override-channels \
    -c file://$MINIBUILDDIR/$CHANNEL \
    psi4

# <<<  Docs Feed  >>>

# Upon sucessful docs build, tars it up here and sends to psicode
#   uses double scp because single often fails, even command-line
# The godaddy site keeps changing identities so circumventing check
if [ -d "$CONDABUILDDIR/doc/sphinxman/html" ]; then
    cd $CONDABUILDDIR/doc/sphinxman
    mv html master
    tar -zcf cb-sphinxman.tar.gz master/

    scp -rv -o 'StrictHostKeyChecking no' cb-sphinxman.tar.gz psicode@www.psicode.org:~/machinations/cb-sphinxman.tar.gz
    while [ $? -ne 0 ]; do
        sleep 6
        echo "trying to upload sphinxman"
        scp -rv -o 'StrictHostKeyChecking no' cb-sphinxman.tar.gz psicode@www.psicode.org:~/machinations/cb-sphinxman.tar.gz
    done
fi

# <<<  PSICODE Feed  >>>

CITESDIR=/home/psilocaluser/gits/psi4meta/recent-citing-articles

# Upon sucessful feed build, tars it up here and sends to psicode
#   uses double scp because single often fails, even command-line
if [ -d "$CONDABUILDDIR/doc/sphinxman/feed" ]; then
    if [ -e "$CITESDIR/first_article.txt" ]; then
        cp -f $CITESDIR/first_article.txt $CONDABUILDDIR/doc/sphinxman/feed/
    fi
    if [ -e "$CITESDIR/articles.txt" ]; then
        cp -f $CITESDIR/articles.txt $CONDABUILDDIR/doc/sphinxman/feed/
    fi

    cd $CONDABUILDDIR/doc/sphinxman
    tar -zcf cb-feed.tar.gz feed/

    scp -rv -o 'StrictHostKeyChecking no' cb-feed.tar.gz psicode@www.psicode.org:~/machinations/cb-feed.tar.gz
    while [ $? -ne 0 ]; do
        sleep 6
        echo "trying to upload ghfeed"
        scp -rv -o 'StrictHostKeyChecking no' cb-feed.tar.gz psicode@www.psicode.org:~/machinations/cb-feed.tar.gz
    done
fi

fi

#############
#  STAGE 3  #
#############

# * set VERSION3 above to installer desired version (usually VERSION == VERSION3)
# * items in $NIGHTLYDIR/installer/construct.yaml
#   - match above VERSION3 in "version"
#   - add psi4 to "channels"
#   - uncomment qc/run
#   - false "keep_pkgs"
#   - uncomment "post_install"

if [ $stage == "stage3" ]; then

# <<<  Prep  >>>

export PATH=$MINIBUILDDIR/minicondadrive/bin:$PATH

# <<<  Run Constructor of QC/Run  >>>

conda install --yes conda=4.0.9 constructor=1.2.0
#conda install --yes conda=4.1.6 constructor=1.3.0  # max works  # ready to test
conda list


cd $NIGHTLYDIR
constructor installer
bash psi4conda-$VERSION3-$PLATFORM2-x86_64.sh -b -p $MINIBUILDDIR/minicondatest-$VERSION3

scp -r psi4conda-$VERSION3-$PLATFORM2-x86_64.sh psicode@www.psicode.org:~/html/downloads/psi4conda-$VERSION3-$PLATFORM2-x86_64.sh

set +x
echo TODO:
echo ssh psicode@www.psicode.org
echo cd html/downloads
echo ln -sf psi4conda-$VERSION3-$PLATFORM2-x86_64.sh Psi4conda2-latest-$PLATFORM2.sh
echo TODO: Add versions to download page pill buttons

fi

cd $NIGHTLYDIR
exit 0

# channel notes c. early Nov 2016
# ----
# below getting some from local
#conda build psi4 --keep-old-work -c psi4;psi4/local/test
#anaconda upload /theoryfs2/ds/cdsgroup/buildingminiconda/conda-bld/linux-64/psi4-1.1a1.dev582-py27_0.tar.bz2 --label test
# finds latest
#NOPE conda install psi4 -c psi4/label/test
# gets stuff from both channels
# conda install psi4=1.1a1* -c psi4/label/test -c psi4
#anaconda upload /theoryfs2/ds/cdsgroup/buildingminiconda/conda-bld/linux-64/psi4-1.1a1.dev584+2e796d0-py27_0.tar.bz2 --label test
# w/o trents pkg in way
# conda create -n thrownov3 psi4 -c psi4/label/test -c psi4

#conda env remove -n thrownov3clone

#conda create -n thrownov3clone --file thrownov3-spec.txt 
#psi4 ~/buildingminiconda/envs/thrownov3clone/share/psi4/samples/tu1-h2o-energy/test.in 
#
#LD_PRELOAD=/theoryfs2/ds/cdsgroup/miniconda/envs/thrownov2/lib/libmkl_rt.so stage/theoryfs2/ds/loriab/psi4-compile/install-testnov/bin/psi4 ../tests/tu3-h2o-opt/input.dat 
#
