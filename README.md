# Windows Server 2025 Learning Lab

A turnkey deployment solution for creating a complete Windows Server 2025 lab environment in Azure.

![Windows Server 2025 Lab Environment](https://raw.githubusercontent.com/microsoft/Windows-Server-2025-product-repository/main/WindowsServer2025.jpg)

## Overview

This project provides an automated deployment of a Windows Server 2025 lab environment in Azure, allowing you to explore and learn the newest features of Windows Server 2025. The environment is designed to be cost-effective, secure, and easy to deploy.

### Lab Environment Components

- **Virtual Network**: Isolated network with secured subnets
- **Domain Controllers**: Two Windows Server 2025 Domain Controllers
- **Member Server**: A Windows Server 2025 server joined to the domain
- **Client VM**: A Windows 11 client VM for administration
- **Azure Bastion**: Secure access to VMs without public IPs
- **Key Vault**: Secure storage for credentials

### Pre-installed Tools

All VMs come with the following tools pre-installed:
- PowerShell 7
- Git and GitHub CLI
- Visual Studio Code
- Windows Admin Center v2
- Node.js and Python
- Azure CLI and Azure PowerShell
- Bicep for infrastructure as code

## Quick Start

### Prerequisites

- An Azure subscription (free trial works)
- PowerShell 7+ with Az module installed
- Azure CLI

### Deployment

1. Clone this repository:
   ```powershell
   git clone https://github.com/yourusername/server-2025-learning-lab.git
   cd server-2025-learning-lab
   ```

2. Run the deployment script:
   ```powershell
   ./deploy.ps1
   ```

3. Follow the prompts to customize your deployment.

### Accessing the Lab

After deployment completes (approximately 30-40 minutes):

1. Log in to the Azure Portal
2. Navigate to the resource group created by the deployment
3. Use Azure Bastion to connect to any of the VMs
4. Credentials are stored in the Key Vault

## Lab Architecture

```
+------------------------------------------+
|                  Azure                   |
|                                          |
|  +-------------+       +-------------+   |
|  | Virtual Net |       |  Key Vault  |   |
|  +-------------+       +-------------+   |
|         |                                |
|  +------+------+                         |
|  |             |                         |
|  |  +-------+  |  +-------+  +-------+  |
|  |  |  DC1  |  |  |  DC2  |  |  MEM  |  |
|  |  +-------+  |  +-------+  +-------+  |
|  |             |                         |
|  |  +-------+  |                         |
|  |  |CLIENT |  |                         |
|  |  +-------+  |                         |
|  |             |                         |
|  +-------------+                         |
|                                          |
+------------------------------------------+
```

### Network Configuration

- VNet Address Space: 10.0.0.0/16
- AD Subnet: 10.0.0.0/24
- Server Subnet: 10.0.1.0/24
- Client Subnet: 10.0.2.0/24
- Bastion Subnet: 10.0.3.0/26

### VM Details

| VM | Purpose | IP Address | Operating System |
|----|---------|------------|------------------|
| DC1 | Primary Domain Controller | 10.0.0.4 | Windows Server 2025 |
| DC2 | Secondary Domain Controller | 10.0.0.5 | Windows Server 2025 |
| MEM | Member Server (IIS, etc.) | 10.0.1.4 | Windows Server 2025 |
| CLIENT | Admin Workstation | 10.0.2.4 | Windows 11 |

## Lab Features

### Active Directory

- Fully configured AD DS with two domain controllers
- Demo organizational units, users, and groups
- Default domain admin account for lab administration

### Certificate Services

- AD CS installed on DC1
- Web Enrollment enabled
- Certificate templates for common scenarios

### Additional Components

- Web server (IIS) on the member server
- SSH enabled on all servers
- DNS configuration for internal name resolution

## Cost Optimization

This lab is designed to minimize Azure costs by:

- Using smalldisk VM images
- Implementing right-sized VMs (Standard_D2s_v3)
- No public IPs on VMs (using Bastion for access)
- Easy deployment and teardown for on-demand usage

## Customization

You can customize the lab by modifying the Bicep templates and scripts:

- Change VM sizes or OS versions
- Add additional VMs or services
- Modify the domain structure
- Expand the network configuration

## Troubleshooting

For common issues, see the [Troubleshooting Guide](docs/troubleshooting.md).

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Microsoft for Windows Server 2025
- Azure Bicep community for infrastructure as code templates
- PowerShell community for automation scripts
