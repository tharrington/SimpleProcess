import { LightningElement, api, track } from 'lwc';
import createEnvelopeAsync from '@salesforce/apex/EmbeddedSigningController.createEnvelopeAsync';
import getSenderViewUrl from '@salesforce/apex/EmbeddedSigningController.getSenderViewUrl';

export default class EmbeddedSigning extends LightningElement {
    @api obId = 'a0dgK000004WQmfQAG';              // Onboarding_Document__c ID
    @api contactId = '003gK000001lnTCQAY';          // Signer Contact ID
    @api contentVersionId = '068gK000002v5xtQAA';   // ContentVersion ID (file)

    @track signingUrl = null;

    handleSignClick() {
        const returnUrl = 'https://orgfarm-72731cff39-dev-ed.develop.my.site.com/s/';

        // Step 1: Create and send the envelope
        createEnvelopeAsync({
            onboardingDocId: this.obId,
            contentVersionId: this.contentVersionId,
            contactId: this.contactId
        })
            .then((docuSignId) => {
                console.log('DocuSign ID:', docuSignId);

                // Step 2: Use returned docuSignId to get the sender view URL
                return getSenderViewUrl({
                    docuSignId: docuSignId,
                    returnUrl: returnUrl
                });
            })
            .then((signingUrl) => {
                // this.showToast('Redirecting to sign...', '', 'info');
                console.log('Signing URL:', signingUrl);
                // window.location.href = signingUrl;
                this.signingUrl = signingUrl;
            })
            .catch((error) => {
                console.error('Error launching embedded signing:', error);
                this.showToast('Error', 'Could not launch DocuSign signing flow.', 'error');
            });
    }

    showToast(title, message, variant) {
        const evt = new CustomEvent('showtoast', {
            detail: { title, message, variant }
        });
        this.dispatchEvent(evt);
    }

    get showIframe() {
        return this.signingUrl !== null;
    }
}
