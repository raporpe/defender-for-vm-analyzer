import datetime
import logging
logger = logging.getLogger(__name__)
import os

import azure.functions as func

# import the Azure SDK for Python management
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient

from azure.mgmt.resource import ResourceManagementClient

from . import credential_adapter

DEBUG = os.getenv("DEBUG") == "true"

def main(mytimer: func.TimerRequest) -> None:
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    if mytimer.past_due and DEBUG:
        logging.info('The timer is past due!')

    logging.info('Python timer trigger function ran at %s', utc_timestamp)

    subscription_id = os.getenv('SUBSCRIPTION_ID')

    # Get the number of running Azure VMs in susbscription id
    running_vms = get_databricks_billable_vms(subscription_id)

    # Send the number of running Azure VMs to App Insights 
    logger.info('Billable Databricks VMs: {}'.format(running_vms))

"""

This function gets the number of Databricks billable VMs in a subscription.

"""
def get_databricks_billable_vms(subscription_id):
    credential = DefaultAzureCredential()

    if os.getenv("LOCAL_DEV") == "true":
        credential = credential_adapter.AzureIdentityCredentialAdapter(credential)

    # Get authentication for making queries to Azure Resource Manager
    compute_client = ComputeManagementClient(credential,
                                             subscription_id)
    
    # Initialize the variable to return
    running_databricks_billable_vms = 0

    # Set the VM iterator type hint just for code hints 
    vm : azure.mgmt.compute.v2019_07_01.models._models_py3.VirtualMachine = None

    # Iterate over all the VMs in the subscription
    for vm in compute_client.virtual_machines.list_all():

        logger.info(vm.tags)

        # Get the resource group of the VM for quering the instace_view and get functions
        vm_resource_group = vm.id.split('/')[4]

        if DEBUG:
            logger.info("Checking VM: " + vm.name)


        # Check if the VM might be a Databricks worker
        is_databricks_vm = False
        if vm.tags != None:
            is_databricks_vm = vm.tags["Vendor"] == "Databricks"

        if is_databricks_vm and DEBUG:
            logger.info("The VM {} is a Databricks VM".format(vm.name))
        elif DEBUG:
            logger.info("The VM {} is not a Databricks worker since the 'Vendor' tag was not found \
                         or the 'Vendor' tag is different than 'Databricks'".format(vm.name))
            # Skip this VM since it is not a Databricks worker
            continue

        # --- Now we have to check that this VM is actually being billed by Azure Defender for VM

        # Get the running status of the VM
        vm_status = compute_client.virtual_machines.instance_view(resource_group_name=vm_resource_group,
                                                                  vm_name=vm.name)

        # Check that the statuses parameter has information
        if vm_status.statuses == None:
            logger.error("Cannot read the VM status.\
                         It might be due to incorrect role assigments or permissions.\
                         Both \"Microsoft.Compute/virtualMachines/read\" and\
                         \"Microsoft.Compute/virtualMachines/instanceView/read\" are required.")
            # Skip this VM since it cannot be confirmed to be running
            continue

        # Calculate if this VM is billable
        vm_provisioned = vm.provisioning_state == "Succeeded"
        if not vm_provisioned and DEBUG:
            logger.info("The VM {} is not in Succeeded provisioning state. Current state: {}".format(vm.name, vm.provisioning_state))

        vm_running = vm_status.statuses[1].display_status == "VM running"
        if not vm_running and DEBUG:
            logger.info("The VM {} is not running. Current state: {}".format(vm.name, vm_status.statuses[1].display_status))

        billable_databricks_vm = vm_provisioned and \
            is_databricks_vm and \
            vm_running

        if billable_databricks_vm:
            running_databricks_billable_vms += 1
            logger.info("The VM {} is a billable databricks VM!".format(vm.name))

    return running_databricks_billable_vms
    
