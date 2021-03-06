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
declare -i lumi=$filenum*$nevents/10000+1
declare -i firstEvent=$filenum*$nevents
echo "Event" $firstEvent "lumi" $lumi
basepath=$3
# Download fragment from McM
curl -s -k https://cms-pdmv.cern.ch/mcm/public/restapi/requests/get_fragment/EGM-RunIISpring18GS-00013 --retry 3 --create-dirs -o Configuration/GenProduction/python/EGM-RunIISpring18GS-00013-fragment.py
[ -s Configuration/GenProduction/python/EGM-RunIISpring18GS-00013-fragment.py ] || exit $?;
scram b
cd ../..

gsdfile=EGM-Run3Summer21GS-00013_${filenum}.root 
digifile=EGM-Run3Summer21DRPremix-00013_1_${filenum}.root 
recofile=EGM-Run3Summer21DRPremix-00013_2_${filenum}.root 
minifile=EGM-Run3Summer21MiniAOD-00013_${filenum}.root 

recoKeepCustomize="process.RECOSIMoutput.outputCommands.extend(['keep *_particleFlowCluster*_*_*', 'keep *_mix_MergedTrackTruth_*', 'keep *_ecalDigis*_*_*', 'keep *_genParticles*_*_*'])"
miniKeepCustomize="process.MINIAODSIMoutput.outputCommands.extend(['keep *_particleFlowCluster*_*_*', 'keep *_mix_MergedTrackTruth_*', 'keep *_ecalDigis*_*_*', 'keep *_genParticles*_*_*'])"

cmsDriver.py Configuration/GenProduction/python/EGM-RunIISpring18GS-00013-fragment.py --mc --eventcontent RAWSIM --datatier GEN-SIM --conditions auto:phase1_2021_realistic --beamspot Run3RoundOptics25ns13TeVLowSigmaZ --step GEN,SIM --geometry Extended2021ZeroMaterial --era Run3  --fileout file:$gsdfile -n $nevents --customise_commands "process.RandomNumberGeneratorService.externalLHEProducer.initialSeed=${filenum}\nprocess.generator.PGunParameters.MaxPt=300.\nprocess.generator.psethack='double photon pt 0.01 to 300'\nprocess.source.firstLuminosityBlock=cms.untracked.uint32(${lumi})\nprocess.source.firstEvent=cms.untracked.uint32(${firstEvent})\bprocess.g4SimHits.Physics.G4GeneralProcess=False" --nThreads 4
#xrdcp $gsdfile root://eoscms.cern.ch/${basepath}/GENSIM/$gsdfile

## No PU
cmsDriver.py step1 --mc --eventcontent RAWSIM --pileup NoPileUp --customise Configuration/DataProcessing/Utils.addMonitoring --datatier GEN-SIM-DIGI-RAW --nThreads 4 --fileout file:$gsdfile --conditions auto:phase1_2021_realistic --step DIGI,L1,DIGI2RAW,HLT:GRun --geometry Extended2021ZeroMaterial --era Run3 --filein file:$gsdfile --fileout file:$digifile -n -1

cmsDriver.py step2 --mc --eventcontent RECOSIM --datatier GEN-SIM-RECO --conditions auto:phase1_2021_realistic --step RAW2DIGI,L1Reco,RECO,RECOSIM --nThreads 4 --geometry Extended2021ZeroMaterial --era Run3 --filein file:$digifile --fileout file:$recofile -n -1 --customise_commands "$recoKeepCustomize"
##xrdcp $recofile root://eoscms.cern.ch/${basepath}/RECO/$recofile

cmsDriver.py step1 --mc --eventcontent MINIAODSIM --datatier MINIAODSIM --conditions auto:phase1_2021_realistic --step PAT --nThreads 4 --era Run3 --filein file:$recofile --fileout file:$minifile -n -1 --customise_commands "$miniKeepCustomize"
xrdcp $minifile root://eoscms.cern.ch/${basepath}/$minifile 
rm *.root
