---
title: "Windows 11 VM Entra ID-Joined for OpenStack in Production Environment"
description: "Spin up Windows 11 25H2 VMs that are Entra ID joined, app-provisioned, and RDP-ready with M365 credentials from first boot — without any Intune or MDM management."
category: "utility"
tags: ["windows", "garbage", "virtualisation", "entra-id"]
created: 2026-05-25
---

Spin up Windows 11 25H2 VMs that are Entra ID joined, Intune-enrolled, app-provisioned, and RDP-ready with M365 credentials from first boot.

---

## Prerequisites

### Licensing
- **Microsoft 365 E3 or E5** (includes Intune + Entra ID P1)
- Or **Intune standalone** + **Entra ID P1** minimum
- Users need an assigned Intune license in M365 admin center

### Admin Access Required
- Global Admin or Intune Admin + Entra ID admin role
- Access to https://intune.microsoft.com
- Access to https://entra.microsoft.com

### Tools to Install on Your Build Machine
```
winget install Microsoft.WindowsADK
winget install Microsoft.WindowsADK.WinPE
winget install Microsoft.Sysinternals
```

---

## Phase 1 — Build the Reference (Golden) VM

### 1.1 Create the Reference VM

Create a VM on your hypervisor (OpenStack, Hyper-V, VMware, Proxmox — procedure is the same):

| Setting | Value |
|---|---|
| CPU | 4 vCPU minimum |
| RAM | 8 GB minimum |
| Disk | 64 GB+ (thin-provisioned is fine) |
| Firmware | UEFI + Secure Boot |
| TPM | vTPM 2.0 — required by Windows 11 OS, not by Intune |
| NIC | Connected to internet-accessible network |
| Boot | Mount `Win11_25H2_English_x64_v2.iso` |

### 1.2 Install Windows — Skip the Microsoft Account Screen

At the OOBE "Let's connect to a network" screen:

1. Press `Shift + F10` to open CMD
2. Run:
   ```cmd
   OOBE\BYPASSNRO
   ```
3. VM reboots — this time choose **"I don't have internet"** → **"Continue with limited setup"**
4. Create a **local admin account** (e.g., `localadmin` / strong password)
   - This account is temporary — it is for building only
5. Complete setup, skip all optional sign-in prompts

### 1.3 Post-Install Configuration (as localadmin)

**Enable RDP:**
```powershell
# Enable RDP
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0

# Enable RDP through Windows Firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

# Disable NLA — required for Entra ID RDP authentication to work
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0

# Set TLS as the security layer
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "SecurityLayer" -Value 2
```

**Enable Entra ID RDP authentication:**
```powershell
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
If (!(Test-Path $regPath)) { New-Item -Path $regPath -Force }
Set-ItemProperty -Path $regPath -Name "fAllowToGetHelp" -Value 1

New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" `
  -Name "AllowRemoteRPC" -Value 1 -PropertyType DWORD -Force
```

**Disable Fast Startup (prevents clean Sysprep):**
```powershell
powercfg /hibernate off
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Value 0
```

**Set time zone and regional settings:**
```powershell
Set-TimeZone -Id "GMT Standard Time"   # adjust as needed
Set-WinUILanguageOverride -Language en-US
```

**Configure Windows Update — defer feature updates, allow security patches:**
```powershell
$wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
If (!(Test-Path $wuPath)) { New-Item -Path $wuPath -Force }
Set-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -Value 0
Set-ItemProperty -Path $wuPath -Name "AUOptions" -Value 3
```

### 1.4 Install Your Required Apps

Install all apps you want pre-baked into the image. Use `winget` or direct installers:

```powershell
# Adjust to your app list
winget install --id=Microsoft.Teams --silent --accept-source-agreements --accept-package-agreements
winget install --id=Mozilla.Firefox --silent --accept-source-agreements
winget install --id=7zip.7zip --silent --accept-source-agreements
winget install --id=VideoLAN.VLC --silent --accept-source-agreements
```

**Microsoft 365 Apps via Office Deployment Tool:**

Save the following as `config.xml`, then run `setup.exe /configure config.xml`:

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

### 1.5 Clean Up Before Sysprep

```powershell
# Clear Windows Update cache
Stop-Service wuauserv
Remove-Item -Path "C:\Windows\SoftwareDistribution\Download\*" -Recurse -Force
Start-Service wuauserv

# Clear temp files
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Clear event logs
Get-EventLog -LogName * | ForEach { Clear-EventLog $_.Log }
```

---

## Phase 2 — Sysprep and Image Capture

### 2.1 Create an Unattend.xml (Answer File)

This automates OOBE on every new VM deployment so it auto-joins Entra ID and enrolls in Intune.

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

> `HideOnlineAccountScreens=false` is what triggers the Entra ID OOBE sign-in. The user who signs in at first boot becomes the primary user and the device joins your tenant automatically.

### 2.2 Run Sysprep

```cmd
C:\Windows\System32\Sysprep\sysprep.exe /oobe /generalize /shutdown /unattend:C:\Windows\System32\Sysprep\unattend.xml
```

- `/oobe` — triggers OOBE on next boot
- `/generalize` — removes hardware-specific info, resets SIDs
- `/shutdown` — powers off cleanly after completion

**Wait for the VM to fully shut down before capturing the image.**

### 2.3 Capture the Disk Image

**OpenNebula:**

After Sysprep shuts down the VM it enters POWEROFF state. Identify the Windows disk ID (not the ISO or context drive):

```bash
onevm show <vm-id>
# Look for the installation disk under VM DISKS — note its ID (e.g. 1)
```

Save that disk as a new reusable image:

```bash
onevm disk-saveas <vm-id> <disk-id> "win11-25h2-golden-$(date +%Y%m%d)"
```

Monitor until `STATE = ready`:

```bash
# The command prints the new image ID — use it here
watch oneimage show <new-image-id>
```

Once ready, terminate the build VM (the image is now independent of it):

```bash
onevm terminate <vm-id>
```

The new image will appear in `oneimage list` as TYPE: OS and is ready to use in VM templates. Do not include the Windows ISO or context disk when building templates from the golden image — only the saved disk is needed.

**OpenStack:**
```bash
# Create a reusable image from the stopped VM
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
  "win11-25h2-intune-golden"
```

**Hyper-V / VMware — via DISM from WinPE:**
```cmd
Dism /Capture-Image /ImageFile:D:\win11-golden.wim /CaptureDir:C:\ /Name:"Win11 Golden"
```

---

## Phase 3 — Intune & Entra ID Configuration

### 3.1 Configure Entra ID for Automatic MDM Enrollment

In https://entra.microsoft.com:

1. **Identity** → **Devices** → **Device Settings**
   - "Users may join devices to Azure AD" → **All** (or a specific group)
   - Set maximum devices per user as appropriate

2. **Identity** → **Mobility (MDM and MAM)** → **Microsoft Intune**
   - MDM User scope → **All** (or scoped group)
   - Leave MDM URLs as defaults (auto-populated)
   - Click **Save**

This ensures that when a user signs in during OOBE, the device **automatically enrolls in Intune** without extra steps.

### 3.2 Configure Intune — Device Configuration Profiles

In https://intune.microsoft.com:

#### Profile 1: Enable RDP via Policy

**Devices** → **Configuration** → **Create** → **New Policy**
- Platform: Windows 10 and later
- Profile type: Settings catalog

Search and configure:
```
Remote Desktop Services > Allow users to connect remotely using Remote Desktop Services = Enabled
Remote Desktop Services > Require user authentication for remote connections using NLA = Disabled
```

#### Profile 2: Add Users to Remote Desktop Users Group

**Devices** → **Configuration** → **Create** → **New Policy**
- Platform: Windows 10 and later
- Profile type: **Local users and groups**

Configure:
- Group: `Remote Desktop Users`
- Action: `Add (Update)`
- Members: your Entra ID user group (e.g., `AzureAD\domain-users@yourtenant.onmicrosoft.com`)

> This is the key step that grants M365 users the right to RDP into these VMs.

#### Profile 3: RDP Security via Custom OMA-URI

**Devices** → **Configuration** → **Create** → **Custom**

| Name | OMA-URI | Data type | Value |
|---|---|---|---|
| RDP Enable | `./Device/Vendor/MSFT/Policy/Config/RemoteDesktop/AllowRemoteDesktop` | Integer | 1 |
| RDP NLA Off | `./Device/Vendor/MSFT/Policy/Config/RemoteDesktopServices/RequireUserAuthenticationForRemoteConnections` | Integer | 0 |

### 3.3 Deploy Apps via Intune

**Apps** → **All Apps** → **Add**

- **Microsoft 365 Apps**: use the built-in M365 Apps for Windows connector — no packaging needed
- **Win32 apps**: package as `.intunewin` using the [Microsoft Win32 Content Prep Tool](https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool):
  ```cmd
  IntuneWinAppUtil.exe -c <source_folder> -s <setup_file> -o <output_folder>
  ```
- Assign apps to **device groups** (not user groups) so they install before first user login

### 3.4 Compliance Policy

**Devices** → **Compliance** → **Create Policy** → Windows 10 and later

Recommended minimums:
```
Minimum OS version:                   10.0.26100  (Win11 25H2)
Firewall:                             Required
Antivirus:                            Required
Defender real-time protection:        Required
```

> **Note:** BitLocker and Secure Boot compliance settings are not supported on VMs managed via Intune — Microsoft explicitly excludes any configuration that relies on hardware TPM or DFCI. Do not add them to the policy or they will permanently mark VMs as non-compliant.

Assign to your Windows VM device group.

---

## Phase 4 — Windows Autopilot

Autopilot registers VMs so they enroll in Intune automatically on first boot without any manual IT steps.

### 4.1 Get the Hardware Hash

Boot the new VM and run this before the user signs in:

```powershell
Install-Script -Name Get-WindowsAutopilotInfo -Force
Get-WindowsAutopilotInfo -OutputFile C:\autopilot-hash.csv
```

### 4.2 Import into Autopilot

**Manual (per VM):**
In Intune: **Devices** → **Enrollment** → **Windows** → **Windows Autopilot** → **Devices** → **Import**
Upload `autopilot-hash.csv`.

**Automated (via Microsoft Graph PowerShell):**
```powershell
Connect-MgGraph -Scopes "DeviceManagementServiceConfig.ReadWrite.All"

$hash = (Get-WindowsAutopilotInfo)[0]
New-MgDeviceManagementWindowsAutopilotDeviceIdentity `
  -HardwareIdentifier $hash.DeviceID `
  -SerialNumber $hash.SerialNumber
```

### 4.3 Create an Autopilot Deployment Profile
Change utility panel to fixed full-viewport layout
**Devices** → **Enrollment** → **Windows** → **Deployment Profiles** → **Create**

| Setting | Value |
|---|---|
| Deployment mode | User-driven |
| Join to Azure AD as | Azure AD joined |
| EULA | Hide |
| Privacy settings | Hide |
| Hide change account options | Yes |
| User account type | Standard |
| Apply device name template | e.g., `INESC-%RAND:5%` |

Assign to your Autopilot device group.

---

## Phase 5 — Deploy a New VM

### 5.1 Instantiate from Golden Image

**OpenStack:**
```bash
openstack server create \
  --image "win11-25h2-intune-golden" \
  --flavor <flavor-with-4vcpu-8gb> \
  --network <your-network> \
  --security-group <rdp-allowed-sg> \
  "win11-vm-$(date +%Y%m%d-%H%M)"
```

Ensure your security group allows:
- TCP 3389 inbound (RDP) — from your trusted IP range only, not `0.0.0.0/0`
- TCP 443 outbound (Intune/Entra ID communication)
- TCP/UDP 53 outbound (DNS)

### 5.2 What Happens at First Boot

1. VM boots into OOBE (Sysprep reset it)
2. User is presented with **"Sign in with Microsoft"** screen
3. User enters their **M365 email + password + MFA**
4. Windows joins **Entra ID** automatically
5. Intune enrollment kicks off automatically (MDM auto-enroll)
6. Autopilot profile is applied — EULA and privacy screens hidden
7. Intune pushes **configuration profiles** (RDP settings, group memberships)
8. Intune installs **assigned apps**
9. Desktop appears — VM is ready

Steps 5–8 run in the background after the desktop appears — the Enrollment Status Page (ESP) is not supported on VMs. Apps and profiles will finish applying within 5–15 minutes; the user can work immediately but may notice apps appearing as Intune delivers them.

---

## Phase 6 — Connecting via RDP with M365 Credentials

### RDP File

Create a `connect-inesc-vm.rdp` file with these properties and distribute to users:

```
full address:s:<vm-ip-or-hostname>
username:s:AzureAD\user@yourtenant.onmicrosoft.com
enablecredsspsupport:i:0
authentication level:i:2
targetisaadjoined:i:1
```

> `targetisaadjoined:i:1` is required — it tells the RDP client this is an Entra ID joined machine and handles token-based auth instead of NTLM/Kerberos.

### Via Command Line

```cmd
mstsc /v:<vm-ip>
```

Then enter credentials as `AzureAD\user@yourtenant.onmicrosoft.com`.

### Via Windows App (Recommended)

The **Windows App** (formerly Remote Desktop client) handles Entra ID auth natively without needing `.rdp` property flags. Download from the Microsoft Store or https://aka.ms/AVDWindowsDesktop.

### What the User Sees

1. Double-click the `.rdp` file or connect via Windows App
2. Windows prompts for M365 credentials (or SSO if the client is also Entra joined)
3. MFA challenge (if Conditional Access is configured)
4. RDP session opens — logged in as their M365 identity

---

## Phase 7 — Ongoing Management

### Updating the Golden Image

1. Deploy a VM from the current golden image
2. Sign in with `localadmin` (local account, not M365)
3. Apply changes
4. Run Sysprep again: `/oobe /generalize /shutdown`
5. Capture new image with a date suffix
6. Keep last 2 versions for rollback

### Monitoring in Intune

- **Devices** → **All Devices** — enrollment status and compliance state
- **Reports** → **Device compliance** — compliance per device
- **Apps** → **Monitor** → **App install status** — per-app deployment status

### Conditional Access (Recommended)

In Entra ID → **Security** → **Conditional Access** → **New Policy**

Require for RDP access:
- Compliant device (passes Intune compliance policy)
- MFA
- Trusted network location (optional — restrict to VPN/office IP range)

---

## Checklist

```
[ ] Entra ID: MDM auto-enrollment configured
[ ] Entra ID: Device join allowed for target users
[ ] Intune: RDP configuration profile deployed
[ ] Intune: Local group (Remote Desktop Users) policy with M365 group
[ ] Intune: Compliance policy assigned to device group
[ ] Intune: Apps assigned to device group
[ ] Autopilot: Deployment profile created (user-driven, AAD joined)
[ ] Golden image: Sysprep'd with unattend.xml
[ ] Golden image: RDP enabled + NLA disabled in registry
[ ] Golden image: Apps pre-installed
[ ] OpenStack: Security group with TCP 3389 open to trusted IPs only
[ ] RDP client: .rdp file includes targetisaadjoined:i:1
[ ] Test: Full OOBE → Entra join → Intune enroll → RDP login flow
```

---

## Key Gotchas

| Issue | Fix |
|---|---|
| RDP won't accept M365 credentials | Add `targetisaadjoined:i:1` to `.rdp` file |
| "Your credentials did not work" on RDP | Ensure NLA is disabled (`UserAuthentication=0`) and user is in Remote Desktop Users group |
| Device doesn't enroll in Intune after Entra join | Check MDM user scope in Entra ID → Mobility is set to All |
| Autopilot profile not applying | Device hardware hash must be imported **before** first boot |
| Apps not installing before user desktop | Assign apps to device groups, not user groups; enable ESP blocking |
| Sysprep fails | Remove Store apps tied to user accounts: `Get-AppxPackage | Remove-AppxPackage` for problematic ones |
| VM not contactable via RDP after deploy | Check OpenStack security group — TCP 3389 must be open inbound |
