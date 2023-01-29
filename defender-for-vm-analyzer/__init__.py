import datetime
import logging
logger = logging.getLogger(__name__)
import os

from . import credential_adapter

import azure.functions as func

# import the Azure SDK for Python management
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient

from azure.mgmt.resource import ResourceManagementClient


def main(mytimer: func.TimerRequest) -> None:
    utc_timestamp = datetime.datetime.utcnow().replace(
        tzinfo=datetime.timezone.utc).isoformat()

    if mytimer.past_due:
        logging.info('The timer is past due!')

    logging.info('Python timer trigger function ran at %s', utc_timestamp)

    subscription_id = os.getenv('SUBSCRIPTION_ID')

    # Get the number of running Azure VMs in susbscription id
    running_vms = get_running_vms(subscription_id)

    # Send the number of running Azure VMs to App Insights 
    logger.info('Running VMs: %s', running_vms, extra={'custom_dimensions': {'running': running_vms}})


def get_running_vms(subscription_id):
    # Get the number of running Azure VMs in susbscription id
    credentials = DefaultAzureCredential()

    # Use adapter to avoid the following error: 'DefaultAzureCredential' object has no attribute 'signed_session'
    wrapped_credential = credential_adapter.AzureIdentityCredentialAdapter(credentials)


    compute_client = ComputeManagementClient(wrapped_credential,
                                             subscription_id)
    running_vms = 0

    vm : azure.mgmt.compute.v2019_07_01.models._models_py3.VirtualMachine = None

    for vm in compute_client.virtual_machines.list_all():
        vm_resource_group = vm.id.split('/')[4]
        logger.warn(vm.name)

        # Get the running status of the VM
        vm_status = compute_client.virtual_machines.instance_view(resource_group_name=vm_resource_group,
                                                                  vm_name=vm.name)

        logger.warn(vm_status.statuses[1].display_status)

        billable_databricks_vm = vm.provisioning_state == "Succeeded" and \
            vm.plan == "DatabricksWorker" and \
            vm_status.statuses[1].display_status == "VM running"

        if billable_databricks_vm:
            running_vms += 1
            logger.info("The VM {} is a billable databricks VM".format(vm.name))

    return running_vms
    
