# Defender for VM Analyzer

This tool, created by Raúl Portugués del Peño (Cloud Solution Architect at Microsoft) **analyzes the number of hours a Databricks PaaS VM is running**. The purpose of this analysis is to **determine the additional cost** that would be incurred if Azure Defender for VMs were enabled at the subscription level.

> Defender for VMs cannot be enabled as of today (2022) in specific VMs: the only option is to enable it at the subscription level, which includes those VMs created by Databricks.

Since the Databricks VMs are constantly being created and deleted, it is **not trivial** to calculate the cost and this is the __raison d'etre__ for this tool.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fraporpe%2Fdefender-for-vm-analyzer%2Fmain%2Finfra.json)

## How it works
<p align="center">
    <img src="https://user-images.githubusercontent.com/6137860/215767008-40400a32-2c40-4543-b55f-7d78a019859c.png" width=75% height=75%>
</p>

1. The App Function is triggered by a **time trigger at the start of every minute**.
2. The App Function checks the last execution time and stops if it ran less time ago than the **Execution Interval Minutes** field specified during setup.
3. The App Function uses the managed identity to call the [**Azure Resource Manager API**](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/overview) asking for a list of all the VMs in the subscription. The managed identity has the role ```def-vm-analyzer-read-vm-metadata``` assigned.
4. A list of all the VMs is retrieved. And each VM is checked for the status (since only running VMs are billed).
5. The total number of billable Databricks VMs is calculated and **logged into the Log Analytics Workspace**.
6. The user checks the results in the bashboard or performs a KQL query (the query is the __How to use__ section) to get the final cost calculation.

- In summary, this solution **logs the number of billable Databricks VMs every N minutes** (where N is the **Execution Interval Minutes** field). Currently, this is the only way to calculate this metric since Azure Resource Graph does not hold historical data regarding the number of running VMs for a given time and that historic has to be built.

### Things to consider

- This app function will make N+1 (where N is the number of VMs in the subscription) queries to the **Azure Resource Manager API** per execution. This API has [**limits**](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/request-limits-and-throttling) per identity, subscription and tenant so calls from other should not be affected. This is the reason why it is important to increase the **Execution Interval Minutes** field in critial scenarios.
- One drawback of this solution is that **it needs to be deployed for a month to calculate the monthly cost**. One possible workaround is to extrapolate the cost of a week to a month.
- The role ```def-vm-analyzer-read-vm-metadata``` is created automatically with the rest of resources and only has two permissions: ```Microsoft.Compute/virtualMachines/read``` and ```Microsoft.Compute/virtualMachines/instanceView/read```. 

## Requirements

- Owner role on the subscription where the solution will be deployed.

## How to Use

1. Click the **__Deploy to Azure__** blue button in a separate window (hold the control key while clicking it).
2. If prompted, login with your credentials that have permissions on the subscription. Select the region to deploy. In the **Execution Interval Minutes** field leave the default value if you have less than 500 VMs. In case you have more, a 10 minute interval is recommended. This interval is important for detecting VMs that might only be running for some minutes and are billed an hour by Defender for Server.
3. All the resources are deployed to a resource group whose name starts with ```def-vm-analyzer-xxxxx```. Check if there was any error in the deployment.
4. Check that the App Function is running by clicking on the "Functions" blade and then in ```defender-for-vm-analyzer```. Click the **Monitor** blade and wait for the function to run at least once (it runs at the start of every minute). Confirm that no exceptions are thrown.

> In case you find the error ```"Cannot read the VM status. It might be due to incorrect role assigments or permissions. Both "Microsoft.Compute/virtualMachines/read" and "Microsoft.Compute/virtualMachines/instanceView/read" are required."``` or any other permission related error, go to the subscription resource and check in the IAM blade that the managed identity ```def-vm-analyzer-xxxxx-identity``` has the role ```def-vm-analyzer-read-vm-metadata```. **The role assignment may fail during the deployment and this step might be necessary.**

5. You can now go back to the resource group and look for the dashboard whose name is ```def-vm-analyzer-xxxxx-dashboard```. There you can check the results in the tile whose name is **Defender for Server cost for Databricks VMs**. This metric is in dollars and is calculated using the following query:

```sql
let defenderForVMHourlyCost = 0.02;
let TotalHours = toscalar(AppTraces 
| where Message startswith "Billable Databricks VMs: "
| project TimeGenerated, DatabricksVMCount = extract("[0-9]+", 0, Message)
| summarize max(DatabricksVMCount) by bin(TimeGenerated, 1h)
| summarize TotalHours = sum(toint(max_DatabricksVMCount)));
print TotalCost = TotalHours*defenderForVMHourlyCost
```

This calculates the cost of Azure Defender for Server for the Databricks VMs **for the Time Range selected at the top**. Remember that if you want to calculate the total cost for a month, the solution will have to be running for a month.

## What is deployed?

One resource group with the name ```def-vm-analyzer-xxxxx``` will be created with the following resources inside:

![image](https://user-images.githubusercontent.com/6137860/217552526-4b8c53e4-4d84-4194-9480-e1038c6f5809.png)

Also, one role with the name ```def-vm-analyzer-read-vm-metadata``` is created and assigned to the managed identity.


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
