# Defender for VM Analyzer

This tool, created by Raúl Portugués del Peño (Cloud Solution Architect at Microsoft) **analyzes the number of hours a Databricks PaaS VM is running**. The purpose of this analysis is to **determine the additional cost** that would be incurred if Azure Defender for VMs were enabled at the subscription level.

> Defender for VMs cannot be enabled as of today (2022) in specific VMs: the only option is to enable it at the subscription level, which includes those VMs created by Databricks.

Since the Databricks VMs are constantly being created and deleted, it is **not trivial** to calculate the cost and this is the raison d'etre for this tool.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fraporpe%2Fdefender-for-vm-analyzer%2Fmain%2Finfra.json)

## How it works
<p align="center">
    <img src="https://user-images.githubusercontent.com/6137860/215767008-40400a32-2c40-4543-b55f-7d78a019859c.png" width=75% height=75%>
</p>

1. The Function App is triggered by a **time trigger at the start of every minute**.
2. The Function App uses the managed identity to call the Azure management API asking for a list of all the VMs in the subscription. The managed identity has the role ```def-vm-analyzer-read-vm-metadata``` assigned.
3. A list of all the VMs is retrieved.
4. The total number of billable Databricks VMs is calculated and **logged into a Log Analytics Workspace**.
5. The user performs a KQL query (the query is the __How to use__ section) to get the final cost calculation.

- In summary, this solution **logs the number of billable Databricks VMs for every minute**. Currently, this is the only way to calculate this metric since Azure Resource Graph does not hold historical data regarding the number of running VMs for a given time.
- One drawback of this solution is that **it needs to be deployed for a month to calculate the monthly cost**. One solution is to extrapolate the cost of a week to a month.
- The role ```def-vm-analyzer-read-vm-metadata``` is created automatically with the rest of resources and only has two permissions: ```Microsoft.Compute/virtualMachines/read``` and ```Microsoft.Compute/virtualMachines/instanceView/read```.

## Requirements

- Owner role on the subscription where the solution will be deployed.

## How to Use

1. Click the "Deploy to Azure" blue button and follow the steps to initiate deployment.
2. All the resources are deployed to a resource group whose name starts with ```def-vm-analyzer-xxxxx```. Check if there was any error in the deployment.
3. Check that the Azure Function is running by clicking on the "Functions" blade and then in ```defender-for-vm-analyzer```. Click the "Monitor" blade and wait for the function to run at least once (it runs at the start of every minute). Confirm that it is running correctly by scrolling to the botton and verifying that the following log is written: "Billable Databricks VMs: X"

> In case you find the error ```"Cannot read the VM status. It might be due to incorrect role assigments or permissions. Both "Microsoft.Compute/virtualMachines/read" and "Microsoft.Compute/virtualMachines/instanceView/read" are required."``` or any other permission related error, go to the subscription resource and check in the IAM blade that the managed identity "def-vm-analyzer-xxxxx-identity" has the role "def-vm-analyzer-read-vm-metadata".

4. You can now go back to the resource group and look for the Log analytics workspace. Perform the following KQL query to see the current consumption:

```sql
let defenderForVMHourlyCost = 0.02;
let TotalHours = toscalar(AppTraces 
| where Message startswith "Billable Databricks VMs: "
| project TimeGenerated, DatabricksVMCount = extract("[0-9]+", 0, Message)
| summarize max(DatabricksVMCount) by bin(TimeGenerated, 1h)
| summarize TotalHours = sum(toint(max_DatabricksVMCount)));
print TotalCost = TotalHours*defenderForVMHourlyCost
```

This will calculate the cost of Azure Defender for VM for the Databricks VMs **for the Time Range selected at the top**. Remember that if you want to calculate the total cost for a month, the solution will have to be running for a month.

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
- Thanks to Yanina Falcón for the original idea and the dashboard resource graph queries
- Thanks to David Wahby for helping me during the development process.
