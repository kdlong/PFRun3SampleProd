Universe             = vanilla
Executable           = doublePhotonGun_noMaterial_noPU_12_0.sh
GetEnv               = false

ShouldTransferFiles  = no
request_memory       = 8000
request_disk         = 2048000
request_cpus         = 4
use_x509userproxy = True
+JobFlavour = "workday"
transfer_output_files = No

Arguments = $(Process) 1000 /store/group/phys_pf/Run3PreparationSamples/EGMRegession
output = logs_doublePhotonGun_noMaterial_noPU_12_0/job$(Process).out
error = logs_doublePhotonGun_noMaterial_noPU_12_0/job$(Process).err
Log = logs_doublePhotonGun_noMaterial_noPU_12_0/job$(Process).log

Queue 110
