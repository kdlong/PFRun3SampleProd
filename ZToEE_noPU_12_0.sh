#!/bin/bash
echo "Starting the job"
export SCRAM_ARCH=slc7_amd64_gcc900
source /cvmfs/cms.cern.ch/cmsset_default.sh
if [ -r CMSSW_12_0_0/src ] ; then
  echo release CMSSW_12_0_0 already exists
else
  scram p CMSSW CMSSW_12_0_0
fi
cd CMSSW_12_0_0/src
eval `scram runtime -sh`

filenum=$1
nevents=$2
# use 10000 events/lumi
declare -i lumi=$filenum*10000/$nevents+1
declare -i firstEvent=$filenum*$nevents
echo "Event" $firstEvent "lumi" $lumi
basepath=$3
customizeReco=""
if [[ $4 -gt 0 ]]; then
    customizeReco="--customise_command process.TrajectoryFilterForElectrons.minimumNumberOfHits=cms.int32(3)\nprocess.GsfElectronFittingSmoother.MinNumberOfHits=cms.int32(3)"
fi
# Download fragment from McM
curl -s -k https://cms-pdmv.cern.ch/mcm/public/restapi/requests/get_fragment/EGM-Run3Winter21GS-00002 --retry 3 --create-dirs -o Configuration/GenProduction/python/EGM-Run3Winter21GS-00002-fragment.py
[ -s Configuration/GenProduction/python/EGM-Run3Winter21GS-00002-fragment.py ] || exit $?;
scram b
cd ../..

gsdfile=EGM-Run3Summer21GS-00002_${filenum}.root 
digifile=EGM-Run3Summer21DRPremix-00002_1_${filenum}.root 
recofile=EGM-Run3Summer21DRPremix-00002_2_${filenum}.root 
minifile=EGM-Run3Summer21MiniAOD-00002_${filenum}.root 

cmsDriver.py Configuration/GenProduction/python/EGM-Run3Winter21GS-00002-fragment.py --mc --eventcontent RAWSIM --datatier GEN-SIM --conditions auto:phase1_2021_realistic --beamspot Run3RoundOptics25ns13TeVLowSigmaZ --step GEN,SIM --geometry DB:Extended --era Run3  --fileout file:$gsdfile -n $nevents --customise_commands "process.RandomNumberGeneratorService.externalLHEProducer.initialSeed=${filenum}\nprocess.source.firstLuminosityBlock=cms.untracked.uint32(${lumi})\nprocess.source.firstEvent=cms.untracked.uint32(${firstEvent})"
#xrdcp $gsdfile root://eoscms.cern.ch/${basepath}/GENSIM/$gsdfile

# With PU: 
# cmsDriver.py step1 --mc --eventcontent PREMIXRAW --datatier GEN-SIM-DIGI-RAW --conditions auto:phase1_2021_realistic --step DIGI,DATAMIX,L1,DIGI2RAW,HLT --procModifiers premix_stage2 --nThreads 4 --geometry DB:Extended --datamix PreMix --era Run3  --filein file:EGM-Run3Summer21GS-00002.root --fileout file:EGM-Run3Summer21DRPremix-00002_1.root  --pileup 2022_LHC_Simulation_10h_2h --pileup_input das:/RelValMinBias_14TeV/CMSSW_12_0_0-120X_mcRun3_2021_realistic_v4-v1/GEN-SIM
# No PU
cmsDriver.py step1 --mc --eventcontent RAWSIM --pileup NoPileUp --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-DIGI-RAW --nThreads 4 --fileout file:$gsdfile --conditions auto:phase1_2021_realistic --step DIGI,L1,DIGI2RAW,HLT:GRun --geometry DB:Extended --era Run3 --filein file:$gsdfile --fileout file:$digifile -n -1

cmsDriver.py step2 --mc --eventcontent RECOSIM --datatier GEN-SIM-RECO --conditions auto:phase1_2021_realistic --step RAW2DIGI,L1Reco,RECO,RECOSIM --nThreads 4 --geometry DB:Extended --era Run3 --filein file:$digifile --fileout file:$recofile -n -1 $customizeReco
#xrdcp $recofile root://eoscms.cern.ch/${basepath}/RECO/$recofile

cmsDriver.py step1 --mc --eventcontent MINIAODSIM --datatier MINIAODSIM --conditions auto:phase1_2021_realistic --step PAT --nThreads 4 --era Run3 --filein file:$recofile --fileout file:$minifile -n -1
xrdcp $minifile root://eoscms.cern.ch/${basepath}/MINIAOD/$minifile
rm *.root
