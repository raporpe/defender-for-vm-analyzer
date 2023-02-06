# Basic Python libraries
import datetime
import logging
import os
import requests
import hashlib
import json

# Import the Azure SDK
import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient

from . import credential_adapter

logger = logging.getLogger(__name__)

DEBUG = os.getenv("DEBUG") == "true"

def main(mytimer: func.TimerRequest) -> None:
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    if mytimer.past_due and DEBUG:
        logging.info('The timer is past due!')
        logging.info('Python timer trigger function ran at %s', utc_timestamp)

    subscription_id = os.getenv('SUBSCRIPTION_ID')

    # Get metrics about the execution time. Take start time
    start_time = datetime.datetime.now()

    # Get the number of running Azure VMs in susbscription id
    running_vms = get_databricks_billable_vms(subscription_id)

    # Take the end time for calculating the execution time
    execution_time = datetime.datetime.now() - start_time

    # Send the number of running Azure VMs to App Insights 
    # DO NOT MODIFY THIS LOG, IT IS LATER ANALYZED USING A KUSTO QUERY
    logger.info('Billable Databricks VMs: {}'.format(running_vms))
    
    # Anonymous metrics are sent only if the SEND_ANONYMOUS_METRICS environment variable is set to true
    # The metric only consists of a "Hi!" with a identifier that intraceable to the user/company executing this code
    if os.getenv("SEND_ANONYMOUS_METRICS") == "true":
        send_anonymous_metrics(execution_time=execution_time.total_seconds())


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

        if DEBUG:
            logger.info("Checking VM: " + vm.name)

        # Get the resource group of the VM for quering the instace_view and get functions
        vm_resource_group = vm.id.split('/')[4]

        # Check if the VM might be a Databricks worker
        is_databricks_vm = False
        if vm.tags != None:
            try:
                is_databricks_vm = vm.tags["Vendor"] == "Databricks"
            except KeyError:
                # Does not have the "Vendor" tag
                pass

        if is_databricks_vm and DEBUG:
            logger.info("The VM {} is a Databricks VM".format(vm.name))
        elif DEBUG:
            logger.info("The VM {} is not a Databricks worker since the 'Vendor' tag was not found \
                         or the 'Vendor' tag is different than 'Databricks'".format(vm.name))
            # Skip this VM since it is not a Databricks worker
            continue

        # --- Now we have to check that this VM is actually being billed by Azure Defender for VM

        # Get the running status of the VM
        try:
            vm_status = compute_client.virtual_machines.instance_view(resource_group_name=vm_resource_group,
                                                                  vm_name=vm.name)
        except Exception as e:
            logger.error("Cannot read the VM status.\
                         It might be due to lack of permissions.\
                         Or an error in the API call.: {}".format(e))
            # Skip this VM since it cannot be confirmed to be running
            continue

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

def send_anonymous_metrics (execution_time: float):
    # This id is NOT sensitive information, it is randomly generated and means nothing
    debug_anonymous_identity: str = os.getenv("DEBUG_ANONYMOUS_IDENTITY") or ""
    subscription_id: str = os.getenv('SUBSCRIPTION_ID') or ""

    # For added anonimity we are going to hash it with SHA-512
    # SHA-512 was designed by the NSA and has the approval of the NIST
    hash_function = hashlib.sha512()
    hash_function.update(debug_anonymous_identity.encode('utf-8'))
    hash_function.update(subscription_id.encode('utf-8'))

    # It is not impossible the get back neither the anonymous identity nor the subscription id
    identifier = hash_function.hexdigest()

    data_to_send = {
        "identifier": identifier,
        "execution_time": execution_time
    }

    # If any error happens, do not fail the function
    try:
        requests.post("https://anonymous-metrics-analyzer.azurewebsites.net", data=json.dumps(data_to_send))
    except Exception as e:
        logger.warning("Cannot send anonymous metrics: {}".format(e))


