import { LightningElement, api, wire, track } from 'lwc';
import getCompletedProcesses from '@salesforce/apex/CompletedProcessesCtrl.getCompletedProcesses';

export default class CompletedProcesses extends LightningElement {
    @api recordId;
    @track completedProcesses = [];

    @wire(getCompletedProcesses, { targetObjectId: '$recordId' })
    wiredProcesses({ data, error }) {
        if (data) {
            this.completedProcesses = data.map(proc => ({
                ...proc,
                childSteps: (proc.ChildProcesses__r || []).map(step => ({
                    ...step,
                    stepLabel: `Step ${step.StepNumber__c}: ${step.Name}`
                })),
                expanded: false
            }));
        } else if (error) {
            console.error('Error loading completed processes:', error);
        }
    }

    toggleAccordion(event) {
        const procId = event.currentTarget.dataset.id;
        this.completedProcesses = this.completedProcesses.map(proc => ({
            ...proc,
            expanded: proc.Id === procId ? !proc.expanded : proc.expanded
        }));
    }
}
