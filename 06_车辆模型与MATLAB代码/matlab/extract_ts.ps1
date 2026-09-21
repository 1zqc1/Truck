# extract_ts.ps1 — Extract TruckSim VSB to CSV
param($outName = "ts_run")

$runDir = 'D:\Program Files (x86)\TruckSim\data\Results\Run_b2a91e77-4768-44ed-a4e4-8deb2406300c'
$vsb = [System.IO.File]::ReadAllBytes("$runDir\LastRun.vsb")
$vs = Get-Content "$runDir\LastRun.vs" -Raw | ConvertFrom-Json

$ch = $vs.VsChannelGroup.Channels; $nChan = $ch.Count
$chMap = @{}; for ($i = 0; $i -lt $nChan; $i++) { $chMap[$ch[$i].'Name Aliases'[0]] = $i }
$hdr = 24; $nFrames = [Math]::Floor(($vsb.Length - $hdr) / ($nChan * 4))
$fs = [System.BitConverter]

$outDir = "C:\Users\LENOVO\tanker_trucksim_cosim\simulation_data"
$csvPath = "$outDir\$outName.csv"
$cols = @('Time','Vx','Ay','AVz','Roll_E','Roll_E_2','Steer_SW','Fz_L1','Fz_L2','Fz_R1','Fz_R2','Ay_2','Yaw','Yaw_2')

$sw = [System.IO.StreamWriter]::new($csvPath)
$sw.WriteLine(($cols -join ','))

$maxAy = 0; $maxRoll = 0; $sumVx = 0.0
for ($f = 0; $f -lt $nFrames; $f++) {
    $base = $hdr + $f * $nChan * 4
    $t = $f * $vs.VsChannelGroup.XStep
    $sw.Write("{0:F3}," -f $t)
    for ($j = 1; $j -lt $cols.Count; $j++) {
        if ($chMap.ContainsKey($cols[$j])) {
            $v = $fs::ToSingle($vsb, $base + $chMap[$cols[$j]] * 4)
            $sw.Write("{0:F6}" -f $v)
        } else { $sw.Write("NaN") }
        if ($j -lt $cols.Count - 1) { $sw.Write(',') }
    }
    $sw.WriteLine()
    $sumVx += $fs::ToSingle($vsb, $base + $chMap['Vx'] * 4)
    $ay = [Math]::Abs($fs::ToSingle($vsb, $base + $chMap['Ay'] * 4))
    $roll = [Math]::Abs($fs::ToSingle($vsb, $base + $chMap['Roll_E_2'] * 4))
    if ($ay -gt $maxAy) { $maxAy = $ay }
    if ($roll -gt $maxRoll) { $maxRoll = $roll }
}
$sw.Close()
Write-Host "$outName`: Vx=$([Math]::Round($sumVx/$nFrames,1))km/h |Ay|max=$([Math]::Round($maxAy,4))g |Roll2|max=$([Math]::Round($maxRoll,1))deg Frames=$nFrames"
