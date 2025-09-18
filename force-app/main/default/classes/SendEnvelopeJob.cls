public class SendEnvelopeJob implements Queueable, Database.AllowsCallouts {

    private Id genTemplateId;
    private Id contactId;
    private String roleName;
    private String returnUrl;

    public SendEnvelopeJob(Id genTemplateId, Id contactId, String roleName, String returnUrl) {
        this.genTemplateId = genTemplateId;
        this.contactId = contactId;
        this.roleName = roleName;
        this.returnUrl = returnUrl;
    }

    public void execute(QueueableContext context) {
        try {
            Contact contact = [SELECT Name, Email FROM Contact WHERE Id = :contactId];
            dfsle__GenTemplate__c template = [
                SELECT Name, dfsle__TemplateId__c FROM dfsle__GenTemplate__c
                WHERE Id = :genTemplateId
            ];

            dfsle.UUID templateUUID = dfsle.UUID.parse(template.dfsle__TemplateId__c);
            dfsle.Document templateDoc = dfsle.Document.fromTemplate(templateUUID, template.Name);

            dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity('a0dgK000004UAkPQAW'));
            envelope = envelope.withDocuments(new List<dfsle.Document>{ templateDoc });

            // dfsle.Recipient recipient = dfsle.Recipient.fromSource(
            //     contact.Name,
            //     contact.Email,
            //     null,
            //     's1',
            //     new dfsle.Entity(contactId)
            // );
            dfsle.Recipient recipient = dfsle.Recipient.newEmbeddedSigner();

            envelope = envelope.withRecipients(new List<dfsle.Recipient>{ recipient });

            System.debug('### envelope: ' + envelope);

            // ✅ Send the envelope
            envelope = dfsle.EnvelopeService.sendEnvelope(envelope, true);
            dfsle.UUID envUUID = envelope.docuSignId;

            System.debug('### 222envelope: ' + envelope);
 
            // ✅ Enqueue next job for signing URL
            System.enqueueJob(new GetSigningUrlJob(envUUID, returnUrl));

        } catch (Exception e) {
            System.debug('SendEnvelopeJob error: ' + e.getMessage());
            System.debug('Trace: ' + e.getStackTraceString());
        }
    }
}


/*
Id onboardingDocId = 'a0dgK000004USr3QAG'; // The Onboarding_Document__c record
Id contentVersionId = '068gK000002uRR0QAM'; // The generated file ID
Id contactId = '003gK000001lnTCQAY';        // The signer contact
String returnUrl = 'https://yourapp.com/after-signing'; // Your redirect

// Step 1: Get the ContentVersion (file)
ContentVersion cv = [
    SELECT Id, Title, FileExtension, VersionData
    FROM ContentVersion
    WHERE Id = :contentVersionId
    LIMIT 1
];

// Step 2: Get the Contact (signer)
Contact contact = [
    SELECT Id, Name, Email
    FROM Contact
    WHERE Id = :contactId
    LIMIT 1
];

// Step 3: Create envelope linked to Onboarding_Document__c
dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(
    new dfsle.Entity(onboardingDocId)
);

// Step 4: Add the document from the file
dfsle.Document doc = dfsle.Document.fromFile(cv);

// Step 5: Create signer recipient (embedded)
dfsle.Recipient recipient = dfsle.Recipient.fromSource(
    contact.Name,
    contact.Email,
    null,                 // phone
    's1',             // role
    new dfsle.Entity(contact.Id)
);

envelope = envelope.withRecipients(new List<dfsle.Recipient>{ recipient });
envelope = envelope.withDocuments(new List<dfsle.Document>{ doc });

System.debug('### envelope: ' + envelope);

// Send the envelope
envelope = dfsle.EnvelopeService.sendEnvelope(envelope, true);

*/