import datetime
import logging
logger = logging.getLogger(__name__)
import os

import azure.functions as func

# import the Azure SDK for Python management
from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient

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
    logger.error('Running VMs: %s', running_vms, extra={'custom_dimensions': {'running': running_vms}})


def get_running_vms(subscription_id):
    # Get the number of running Azure VMs in susbscription id
    credential = DefaultAzureCredential()
    compute_client = ComputeManagementClient(credential, subscription_id)
    running_vms = 0
    for vm in compute_client.virtual_machines.list_all():
        vm_resource_group = vm.id.split('/')[4]
        status = compute_client.virtual_machines.instance_view(vm_resource_group, vm.name)
        logger.info("--------------- VM PLAN ----------> " + str(vm.plan))
        if status.statuses[1].display_status == "VM running" and vm.plan == "DatabricksWorker":
            running_vms += 1
    return running_vms
    
