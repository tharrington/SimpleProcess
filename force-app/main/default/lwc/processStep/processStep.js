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

    get hasProcesses() {
        return this.processData && this.processData.length > 0;
    }

    @wire(getTemplates)
    wiredTemplates({ data, error }) {
        if (data) {
            this.templates = data.map(t => ({ label: t.Name, value: t.Id }));
        } else if (error) {
            console.error('Template fetch error:', error);
        }
    }

    @wire(getProcessesForTarget, { targetObjectId: '$recordId' })
    wiredProcesses(result) {
        this.wiredProcessesResult = result;
        const { data, error } = result;
        if (data) {
            this.processData = data;
        } else if (error) {
            console.error('Error loading processes:', error);
        }
    }

    handleTemplateChange(event) {
        this.selectedTemplateId = event.detail.value;
    }

    async handleCreate() {
        try {
            await createProcessFromTemplate({
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
        const processId = event.detail.processId || event.target.dataset.id;
        const newStatus = event.detail.newStatus || event.detail.value;

        this.handleStatusUpdate(processId, newStatus);
    }

    async handleStatusUpdate(processId, newStatus) {
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

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: err.body?.message || err.message,
                    variant: 'error'
                })
            );

            await refreshApex(this.wiredProcessesResult);
        }
    }
}