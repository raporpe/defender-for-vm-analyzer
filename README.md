# Defender for VM Analyzer

This tool, created by Raúl Portugués del Peño (Cloud Solution Architect at Microsoft) **analyzes the number of hours a Databricks PaaS VM is running**. The purpose of this analysis is to **determine the additional cost** that would be incurred if Azure Defender for VMs were enabled at the subscription level.

>>> Defender for VMs cannot be enabled as of today (2022) in specific VMs: the only option is to enable it at the subscription level, which includes those VMs created by Databricks.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fraporpe%2Fdefender-for-vm-analyzer%2Fmain%2Finfra.json)

## Requirements
TODO: List any requirements for using the Defender for VM Analyzer (e.g. software dependencies, operating system compatibility, etc.).

- Owner permissions on the subscription where the solution will be deployed

## How to Use
1. Click the Deploy to Azure button and follow the steps to initiate deployment.
2. All the resources are deployed to a resource group whose name starts with "def-vm-analyzer-xxxxx". Check if there was any error in the deployment.
3. Check that the Azure Function is running by clicking on the "Functions" blade and then in "defender-for-vm-analyzer". Click the "Monitor" blade and wait for the function to run at least once (it runs at the start of every minute). Confirm that it is running correctly by scrolling to the botton and verifying that the following log is written: "Billable Databricks VMs: X"

>> In case you find the error ```"Cannot read the VM status. It might be due to incorrect role assigments or permissions. Both "Microsoft.Compute virtualMachines/read" and "Microsoft.Compute/virtualMachines/instanceView/read" are required."``` or any other permission related error, you can grant the function a system-assigned identity with the Reader role to the whole subscription. It is not the best security practice, so check the code within ```__init.py__``` that is being run in the function. 

4. You can now go back to the resource group and look for the Log analytics workspace. Perform the following KQL query to see the current consumption:


## Contributing
Do not hesitate to make a pull request or contact me at raulpo@microsoft.com


## License
MIT License

Copyright (c) [2023] [Raúl Portugués del Peño]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.


## Credits
Thanks to David Wahby for helping me during the development process. 