---
title: "Windows 11 VM Entra ID-Joined for OpenStack in Production Environment"
description: "Spin up Windows 11 25H2 VMs that are Entra ID joined, app-provisioned, and RDP-ready with M365 credentials from first boot — without any Intune or MDM management."
category: "utility"
tags: ["windows", "garbage", "virtualisation", "entra-id"]
created: 2026-05-25
---

# Windows 11 VM Entra ID-Joined for OpenStack in Production Environment

Spin up Windows 11 25H2 VMs that are Entra ID joined, app-provisioned, and RDP-ready with M365 credentials from first boot — without any Intune or MDM management.

**How it works:** The VM joins Entra ID during OOBE when the user signs in with their M365 account. From that point Windows accepts Entra ID tokens at the RDP prompt, so users type `user@tenant.com` and their M365 password to connect. All configuration that Intune would normally deliver must instead be baked into the golden image.

---

## Prerequisites

### Licensing
- **Microsoft 365** (any tier with Entra ID) — users just need an Entra ID account
- No Intune license required

### Admin Access Required
- Global Admin or Entra ID admin role
- Access to https://entra.microsoft.com

### Tools to Install on Your Build Machine
```
winget install Microsoft.WindowsADK
winget install Microsoft.WindowsADK.WinPE
```

---

## Phase 1 — Build the Reference (Golden) VM

### 1.1 Create the Reference VM

| Setting | Value |
|---|---|
| CPU | 4 vCPU minimum |
| RAM | 8 GB minimum |
| Disk | 64 GB+ (thin-provisioned is fine) |
| Firmware | UEFI + Secure Boot |
| TPM | vTPM 2.0 — required by Windows 11 OS |
| NIC | Connected to internet-accessible network |
| Boot | Mount `Win11_25H2_English_x64_v2.iso` |

### 1.2 Install Windows — Skip the Microsoft Account Screen

At the OOBE "Let's connect to a network" screen:

1. Press `Shift + F10` to open CMD
2. Run:
   ```cmd
   OOBE\BYPASSNRO
   ```
3. VM reboots — choose **"I don't have internet"** → **"Continue with limited setup"**
4. Create a **local admin account** (e.g., `localadmin` / strong password) — temporary, for building only
5. Complete setup, skip all optional sign-in prompts

### 1.3 Post-Install Configuration (as localadmin)

All configuration must be baked into the image — there is no Intune to deliver policy after deployment.

**Enable RDP:**
```powershell
# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
  -Name "fDenyTSConnections" -Value 0

# Enable RDP through Windows Firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Disable NLA — required for Entra ID token-based RDP authentication to work
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
  -Name "UserAuthentication" -Value 0

# Set TLS as the security layer
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' `
  -Name "SecurityLayer" -Value 2
```

**Enable Entra ID RDP authentication:**
```powershell
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
If (!(Test-Path $regPath)) { New-Item -Path $regPath -Force }
Set-ItemProperty -Path $regPath -Name "fAllowToGetHelp" -Value 1

New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
  -Name "AllowRemoteRPC" -Value 1 -PropertyType DWORD -Force
```

**Lock down RDP to trusted IP ranges in the firewall:**
```powershell
# Replace the default wide-open RDP rule with a scoped one
Disable-NetFirewallRule -DisplayGroup "Remote Desktop"

New-NetFirewallRule `
  -DisplayName "RDP - Trusted Only" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 3389 `
  -RemoteAddress "10.0.0.0/8","192.168.0.0/16" `  # adjust to your network
  -Action Allow `
  -Profile Any
```

**Disable Fast Startup (prevents clean Sysprep):**
```powershell
powercfg /hibernate off
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" `
  -Name "HiberbootEnabled" -Value 0
```

**Set time zone and regional settings:**
```powershell
Set-TimeZone -Id "GMT Standard Time"   # adjust as needed
Set-WinUILanguageOverride -Language en-US
```

**Configure Windows Update:**
```powershell
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
If (!(Test-Path $wuPath)) { New-Item -Path $wuPath -Force }
Set-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -Value 0
Set-ItemProperty -Path $wuPath -Name "AUOptions" -Value 3
```

### 1.4 Populate Remote Desktop Users via First-Boot Script

Without Intune there is no policy to add Entra ID accounts to the `Remote Desktop Users` local group. A scheduled task baked into the image handles this: it runs once on first boot after the Entra ID join completes, adds the configured accounts, then deletes itself.

**Save as `C:\Windows\Setup\Scripts\Set-RDPUsers.ps1`:**

```powershell
# Runs once on first boot after Entra ID join.
# Edit $RDPPrincipals to match your tenant users.
# Note: Windows cannot resolve Entra ID group names locally —
# add individual UPNs here, or grant a group local admin rights
# via Entra ID device settings instead (see Phase 3.2).

$RDPPrincipals = @(
    "AzureAD\user1@yourtenant.onmicrosoft.com"
    "AzureAD\user2@yourtenant.onmicrosoft.com"
    # add more as needed
)

foreach ($principal in $RDPPrincipals) {
    try {
        Add-LocalGroupMember -Group "Remote Desktop Users" -Member $principal -ErrorAction Stop
        Write-EventLog -LogName Application -Source "SetupScript" -EntryType Information `
          -EventId 1001 -Message "Added $principal to Remote Desktop Users"
    } catch {
        Write-EventLog -LogName Application -Source "SetupScript" -EntryType Warning `
          -EventId 1002 -Message "Failed to add $principal : $_"
    }
}

Unregister-ScheduledTask -TaskName "SetRDPUsers" -Confirm:$false
```

**Register the scheduled task (survives Sysprep):**

```powershell
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\Set-RDPUsers.ps1"

$trigger = New-ScheduledTaskTrigger -AtStartup

$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 10) -RestartCount 3

Register-ScheduledTask -TaskName "SetRDPUsers" `
  -Action $action `
  -Trigger $trigger `
  -RunLevel Highest `
  -User "SYSTEM" `
  -Settings $settings `
  -Force
```

### 1.5 Install Your Required Apps

All apps must be pre-installed — there is no Intune to deliver them post-enrollment.

```powershell
# Adjust to your app list
winget install --id=Microsoft.Teams --silent --accept-source-agreements --accept-package-agreements
winget install --id=Mozilla.Firefox --silent --accept-source-agreements
winget install --id=7zip.7zip --silent --accept-source-agreements
winget install --id=VideoLAN.VLC --silent --accept-source-agreements
```

**Microsoft 365 Apps via Office Deployment Tool:**

Save as `config.xml`, then run `setup.exe /configure config.xml`:

```xml
<Configuration>
  <Add OfficeClientEdition="64" Channel="MonthlyEnterprise">
    <Product ID="O365ProPlusRetail">
      <Language ID="en-us" />
      <ExcludeApp ID="Groove" />
      <ExcludeApp ID="Lync" />
    </Product>
  </Add>
  <Updates Enabled="TRUE" Channel="MonthlyEnterprise" />
  <Display Level="None" AcceptEULA="TRUE" />
  <Logging Level="Standard" Path="%temp%" />
</Configuration>
```

### 1.6 Clean Up Before Sysprep

```powershell
Stop-Service wuauserv
Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force
Start-Service wuauserv

Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

Get-EventLog -LogName * | ForEach { Clear-EventLog $_.Log }
```

---

## Phase 2 — Sysprep and Image Capture

### 2.1 Create an Unattend.xml

`HideOnlineAccountScreens=false` is what triggers the Entra ID sign-in screen at OOBE. The user who signs in becomes the primary user and the device joins your tenant automatically.

Save as `C:\Windows\System32\Sysprep\unattend.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
        <HideOnlineAccountScreens>false</HideOnlineAccountScreens>
        <!-- false = show AAD sign-in = automatic Entra ID join -->
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>1</ProtectYourPC>
        <SkipUserOOBE>false</SkipUserOOBE>
        <SkipMachineOOBE>false</SkipMachineOOBE>
      </OOBE>
      <TimeZone>GMT Standard Time</TimeZone>
    </component>
    <component name="Microsoft-Windows-International-Core"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <InputLocale>en-US</InputLocale>
      <SystemLocale>en-US</SystemLocale>
      <UILanguage>en-US</UILanguage>
      <UserLocale>en-US</UserLocale>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS">
      <ComputerName>*</ComputerName>
      <!-- * = auto-generate unique name per VM -->
    </component>
  </settings>
</unattend>
```

### 2.2 Run Sysprep

```cmd
C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
```

Wait for the VM to fully shut down before capturing the image.

### 2.3 Capture the Disk Image

**OpenStack:**
```bash
openstack server image create --name "win11-25h2-golden-$(date +%Y%m%d)" <vm-id>

# Or convert and upload a QCOW2 directly
qemu-img convert -O qcow2 /path/to/vm-disk.raw win11-25h2-golden.qcow2

openstack image create \
  --container-format bare \
  --disk-format qcow2 \
  --file win11-25h2-golden.qcow2 \
  --property os_type=windows \
  --property hw_disk_bus=virtio \
  --property hw_vif_model=virtio \
  "win11-25h2-nointune-golden"
```

**Hyper-V / VMware — via DISM from WinPE:**
```cmd
Dism /Capture-Image /ImageFile:D:\win11-golden.wim /CaptureDir:C:\ /Name:"Win11 Golden"
```

---

## Phase 3 — Entra ID Configuration

### 3.1 Allow Device Join and Disable MDM Auto-Enrollment

In https://entra.microsoft.com:

1. **Identity** → **Devices** → **Device Settings**
   - "Users may join devices to Azure AD" → **All** (or a specific group)
   - Set maximum devices per user as appropriate

2. **Identity** → **Mobility (MDM and MAM)** → **Microsoft Intune**
   - MDM User scope → **None**

> If MDM scope is left as All, devices will silently auto-enroll in Intune the moment they join Entra ID — even without Autopilot. Set it to None to keep them unmanaged.

### 3.2 Grant RDP Access to an Entra ID Group (Recommended)

Windows cannot resolve Entra ID security group names locally, so you cannot add a group directly to `Remote Desktop Users`. The workaround is to assign the group as **local administrators** on all Entra ID joined devices via Entra ID device settings — local admins can always RDP.

In https://entra.microsoft.com:

**Identity** → **Devices** → **Device Settings** → **Manage Additional local administrators on all Azure AD joined devices**

Add your security group (e.g., `VM RDP Users`) here. Every member becomes a local admin on every joined device.

If you want RDP-only access without local admin rights, populate `Remote Desktop Users` with individual UPNs via the `Set-RDPUsers.ps1` scheduled task from Phase 1.4 instead.

---

## Phase 4 — Deploy a New VM

### 4.1 Instantiate from Golden Image

**OpenStack:**
```bash
openstack server create \
  --image "win11-25h2-nointune-golden" \
  --flavor <flavor-with-4vcpu-8gb> \
  --network <your-network> \
  --security-group <rdp-allowed-sg> \
  "win11-vm-$(date +%Y%m%d-%H%M)"
```

Security group rules:
- TCP 3389 inbound — from your trusted IP range only, not `0.0.0.0/0`
- TCP 443 outbound (Entra ID sign-in, app licensing)
- TCP/UDP 53 outbound (DNS)

### 4.2 What Happens at First Boot

1. VM boots into OOBE (Sysprep reset it)
2. User is presented with **"Sign in with Microsoft"** screen
3. User enters their **M365 email + password + MFA**
4. Windows joins **Entra ID** automatically
5. The `SetRDPUsers` scheduled task fires on next reboot — adds configured accounts to Remote Desktop Users
6. Desktop appears — VM is ready

There is no Enrollment Status Page and no background Intune policy delivery. The desktop is available as soon as the user signs in.

---

## Phase 5 — Connecting via RDP with M365 Credentials

### RDP File

Create a `connect-inesc-vm.rdp` file and distribute to users:

```
full address:s:<vm-ip-or-hostname>
username:s:AzureAD\user@yourtenant.onmicrosoft.com
enablecredsspsupport:i:0
authentication level:i:2
targetisaadjoined:i:1
```

> `targetisaadjoined:i:1` is required — it tells the RDP client this is an Entra ID joined machine and switches to token-based auth instead of NTLM/Kerberos.

### Via Command Line

```cmd
mstsc /v:<vm-ip>
```

At the credential prompt enter `AzureAD\user@yourtenant.onmicrosoft.com`.

### Via Windows App (Recommended)

The **Windows App** handles Entra ID auth natively — no `.rdp` file properties needed. Users sign in with their M365 account and add the VM as a PC by IP. Download from the Microsoft Store or https://aka.ms/AVDWindowsDesktop.

---

## Phase 6 — Ongoing Management

### Updating the Golden Image

1. Deploy a VM from the current golden image
2. Sign in with `localadmin` (the local build account — not M365)
3. Apply changes
4. Run Sysprep: `/oobe /generalize /shutdown`
5. Capture new image with a date suffix
6. Keep last 2 versions for rollback

### Patching Running VMs

Connect directly and run:
```powershell
Install-Module PSWindowsUpdate -Force
Get-WindowsUpdate -Install -AcceptAll -AutoReboot
```

For bulk patching across the fleet:
```bash
for vm_ip in $(openstack server list -f value -c Networks | grep -oP '\d+\.\d+\.\d+\.\d+'); do
  echo "Patching $vm_ip"
  # trigger via WinRM or scheduled task
done
```

### Conditional Access (Recommended)

Even without Intune you can enforce MFA and trusted network location for all Entra ID sign-ins, covering both OOBE join and ongoing RDP sessions.

In Entra ID → **Security** → **Conditional Access** → **New Policy**

Require:
- MFA
- Trusted network location (restrict to VPN/office IP range)

---

## Checklist


 - Entra ID: Device join allowed for target users
 - Entra ID: MDM scope set to None (prevents auto Intune enrollment)
 - Entra ID: RDP users security group added as local admins on joined devices
 - Golden image: RDP enabled + NLA disabled in registry
 - Golden image: Entra ID RDP auth registry keys set
 - Golden image: Firewall rule locked to trusted IP range
 - Golden image: Set-RDPUsers.ps1 at C:\Windows\Setup\Scripts\
 - Golden image: SetRDPUsers scheduled task registered
 - Golden image: All apps pre-installed
 - Golden image: Sysprep'd with unattend.xml (HideOnlineAccountScreens=false)
 - OpenStack: Security group with TCP 3389 open to trusted IPs only
 - RDP client: .rdp file includes targetisaadjoined:i:1
 - Test: Full OOBE → Entra join → RDP login with M365 credentials
 - Test: SetRDPUsers task ran and deleted itself (Event Viewer → Application → Event ID 1001)


---

## Key Gotchas

| Issue | Fix |
|---|---|
| VM auto-enrolled in Intune after Entra join | MDM scope in Entra ID → Mobility is set to All — change to None |
| RDP won't accept M365 credentials | Add `targetisaadjoined:i:1` to `.rdp` file |
| "Your credentials did not work" on RDP | Ensure NLA is disabled (`UserAuthentication=0`) and account is in Remote Desktop Users |
| Remote Desktop Users group empty after first boot | Check scheduled task ran: Event Viewer → Application → Event ID 1001/1002; verify script path survived Sysprep |
| Can't add Entra ID group to Remote Desktop Users | Windows can't resolve Entra ID group names locally — add individual UPNs in the script, or use Entra ID device settings to make the group local admins instead |
| Sysprep fails | Remove Store apps tied to user accounts: `Get-AppxPackage \| Remove-AppxPackage` |
| VM not reachable via RDP after deploy | Check OpenStack security group — TCP 3389 must be open inbound from your IP |
| App updates require touching every running VM | Correct — without Intune there is no remote delivery; rebuild the image and redeploy, or connect directly to patch |
