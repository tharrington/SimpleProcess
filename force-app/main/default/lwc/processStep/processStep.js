import { LightningElement, api, track, wire } from 'lwc';
import getTemplates from '@salesforce/apex/ProcessStepCtrl.getTemplates';
import createProcessFromTemplate from '@salesforce/apex/ProcessStepCtrl.createProcessFromTemplate';
import getProcessesForTarget from '@salesforce/apex/ProcessStepCtrl.getProcessesForTarget';
import updateProcessStatus from '@salesforce/apex/ProcessStepCtrl.updateProcessStatus';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';


export default class ProcessStep extends LightningElement {
    @api recordId;
    @api objectApiName;

    @track templates = [];
    @track selectedTemplateId = '';
    @track processData = [];

    wiredProcessesResult;

    @track statusMap = {};

    get statusOptions() {
        return [
            { label: 'New', value: 'New' },
            { label: 'In Progress', value: 'In Progress' },
            { label: 'Completed', value: 'Completed' }
        ];
    }

    get isCreateDisabled() {
        return !this.selectedTemplateId;
    }

    // Add this getter to check if there are any processes
    get hasProcesses() {
        return this.processData && this.processData.length > 0;
    }

    @wire(getTemplates)
    wiredTemplates({ data, error }) {
        if (data) {
            this.templates = data.map(t => ({ label: t.Name, value: t.Id }));
        } else {
            console.error('Template fetch error:', error);
        }
    }

    @wire(getProcessesForTarget, { targetObjectId: '$recordId' })
    wiredProcesses(result) {
        this.wiredProcessesResult = result;
        const { data, error } = result;
        if (data) {
            // Filter and transform parent + children
            const topLevel = data
                .filter(p => !p.ParentProcessId__c)
                .map(p => ({
                    ...p,
                    children: p.ChildProcesses__r || []
                }));

            // ✅ Apply custom flags (overdue, custom logic, etc.)
            this.setProcessData(topLevel);
        } else if (error) {
            console.error('Error loading processes:', error);
        }
    }

    setProcessData(data) {
        this.processData = data.map(proc => {
            const children = (proc.ChildProcesses__r || []).map(child => {
                const dueDate = new Date(child.Due_Date__c);
                const now = new Date();
                const isOverdue = dueDate < now;

                return {
                    ...child,
                    isCustomLogic: child.In_Progress_Requirement__c === 'Custom Logic',
                    dueDateClass: isOverdue ? 'slds-text-color_error' : '',
                    stepTitle: `Step ${child.StepNumber__c}: ${child.Name}`
                };
            });

            return {
                ...proc,
                children
            };
        });
    }

    // Event Handlers
    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
    }

    isCustomLogic(requirement) {
        return requirement === 'Custom Logic';
    }

    async handleCreate() {
        try {
            const newId = await createProcessFromTemplate({
                templateId: this.selectedTemplateId,
                targetObjectId: this.recordId,
                targetObjectType: this.objectApiName
            });

            this.selectedTemplateId = '';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Process created successfully',
                    variant: 'success'
                })
            );

            await refreshApex(this.wiredProcessesResult);
        } catch (err) {
            console.error(err);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: err.body?.message || err.message,
                    variant: 'error'
                })
            );
        }
    }

    handleStatusChange(event) {
        const processId = event.target.dataset.id;
        const newStatus = event.detail.value;

        // Track original status
        let originalStatus;
        this.processData = this.processData.map(proc => {
            return {
                ...proc,
                children: proc.children.map(child => {
                    if (child.Id === processId) {
                        originalStatus = child.Status__c;
                        return {
                            ...child,
                            Status__c: newStatus // optimistic update
                        };
                    }
                    return child;
                })
            };
        });

        this.handleStatusUpdate(processId, newStatus, originalStatus);
    }

    async handleStatusUpdate(processId, newStatus, originalStatus) {
        try {
            await updateProcessStatus({ processId, newStatus });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Status Updated',
                    message: `Process status set to ${newStatus}`,
                    variant: 'success'
                })
            );

            await refreshApex(this.wiredProcessesResult);

        } catch (err) {
            console.error('Error updating status:', err);

            // Revert UI to original status
            this.processData = this.processData.map(proc => {
                return {
                    ...proc,
                    children: proc.children.map(child => {
                        if (child.Id === processId) {
                            return {
                                ...child,
                                Status__c: originalStatus
                            };
                        }
                        return child;
                    })
                };
            });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: err.body?.message || err.message,
                    variant: 'error'
                })
            );
        }
    }
}