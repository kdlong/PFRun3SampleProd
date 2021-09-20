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
# Download fragment from McM
curl -s -k https://cms-pdmv.cern.ch/mcm/public/restapi/requests/get_fragment/JME-RunIIWinter19PFCalib16GS-00001 --retry 3 --create-dirs -o Configuration/GenProduction/python/JME-RunIIWinter19PFCalib16GS-00001-fragment.py
[ -s Configuration/GenProduction/python/JME-RunIIWinter19PFCalib16GS-00001-fragment.py ] || exit $?;
scram b
cd ../..

gsfile=JME-RunIIWinter19PFCalib16GS-00001_${filenum}.root 
digifile=JME-Run3Summer21DRPremix-00001_1_${filenum}.root 
recofile=JME-Run3Summer21DRPremix-00001_2_${filenum}.root 

cmsDriver.py Configuration/GenProduction/python/JME-RunIIWinter19PFCalib16GS-00001-fragment.py --mc --eventcontent RAWSIM --datatier GEN-SIM --conditions 120X_mcRun3_2021_realistic_v6 --beamspot Run3RoundOptics25ns13TeVLowSigmaZ --step GEN,SIM --geometry DB:Extended --era Run3  --fileout file:$gsfile -n $nevents --customise_commands "from IOMC.RandomEngine.RandomServiceHelper import RandomNumberServiceHelper;randHelper=RandomNumberServiceHelper(process.RandomNumberGeneratorService);randHelper.populate()\nprocess.source.firstLuminosityBlock=cms.untracked.uint32(${lumi})\nprocess.source.firstEvent=cms.untracked.uint32(${firstEvent})"

# No PU
cmsDriver.py step1 --mc --eventcontent RAWSIM --pileup NoPileUp --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-DIGI-RAW --nThreads 4 --fileout file:$gsfile --conditions 120X_mcRun3_2021_realistic_v6 --step DIGI,L1,DIGI2RAW,HLT:GRun --geometry DB:Extended --era Run3 --filein file:$gsfile --fileout file:$digifile -n -1

cmsDriver.py step2 --mc --eventcontent RECOSIM --datatier GEN-SIM-RECO --conditions 120X_mcRun3_2021_realistic_v6 --step RAW2DIGI,L1Reco,RECO,RECOSIM --nThreads 4 --geometry DB:Extended --era Run3 --filein file:$digifile --fileout file:$recofile -n -1 $customizeReco
xrdcp $recofile root://eoscms.cern.ch/${basepath}/$recofile
rm *.root
