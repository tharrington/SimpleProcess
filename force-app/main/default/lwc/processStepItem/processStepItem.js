import { LightningElement, api, track } from 'lwc';

export default class ProcessStepItem extends LightningElement {
    @api process;
    @api statusOptions;
    
    @track isExpanded = false;

    get stepTitle() {
        return `Step ${this.process.StepNumber}: ${this.process.Name}`;
    }

    get isCustomLogic() {
        return this.process.In_Progress_Requirement === 'Custom Logic';
    }

    get isCompleted() {
        return this.process.Status === 'Completed';
    }

    get dueDateClass() {
        if (!this.process.Due_Date) return '';
        const dueDate = new Date(this.process.Due_Date);
        const now = new Date();
        return dueDate < now ? 'slds-text-color_error' : '';
    }

    get hasChildren() {
        return this.process.children && this.process.children.length > 0;
    }

    get showChildren() {
        return this.hasChildren && this.isExpanded;
    }

    get expandIconName() {
        return this.isExpanded ? 'utility:chevrondown' : 'utility:chevronright';
    }

    toggleChildren() {
        this.isExpanded = !this.isExpanded;
    }

    handleStatusChange(event) {
        // Bubble the event up to parent
        const statusChangeEvent = new CustomEvent('statuschange', {
            detail: {
                processId: event.detail.processId || event.target.dataset.id,
                newStatus: event.detail.newStatus || event.detail.value
            },
            bubbles: true,
            composed: true
        });
        this.dispatchEvent(statusChangeEvent);
    }
}