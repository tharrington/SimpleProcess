public class DocuSignEnvelopeJob implements Queueable, Database.AllowsCallouts {

    private Id genTemplateId;
    private Id contactId;
    private String roleName;
    private String returnUrl;

    public DocuSignEnvelopeJob(Id genTemplateId, Id contactId, String roleName, String returnUrl) {
        this.genTemplateId = genTemplateId;
        this.contactId = contactId;
        this.roleName = roleName;
        this.returnUrl = returnUrl;
    }

    public void execute(QueueableContext context) {
        try {
            Contact contact = [
                SELECT Name, Email FROM Contact WHERE Id = :contactId LIMIT 1
            ];

            dfsle__GenTemplate__c template = [
                SELECT Name, dfsle__TemplateId__c
                FROM dfsle__GenTemplate__c
                WHERE Id = :genTemplateId
                LIMIT 1
            ];

            dfsle.UUID templateUUID = dfsle.UUID.parse(template.dfsle__TemplateId__c);
            dfsle.Document templateDoc = dfsle.Document.fromTemplate(templateUUID, template.Name);

            dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(new dfsle.Entity('a0dgK000004UAkPQAW'));
            envelope = envelope.withDocuments(new List<dfsle.Document>{ templateDoc });

            dfsle.Recipient recipient = dfsle.Recipient.fromSource(
                contact.Name,
                contact.Email,
                null,
                roleName,
                new dfsle.Entity(contactId)
            );

            envelope = envelope.withRecipients(new List<dfsle.Recipient>{ recipient });

            // Step 1 – Send envelope
            envelope = dfsle.EnvelopeService.sendEnvelope(envelope, true);

            // Step 2 – Get signing URL (separate callout after DML is done)
            dfsle.UUID envUUID = envelope.docuSignId;
            Url signingUrl = dfsle.SigningService.getEmbeddedSigningUrl(envUUID, new Url(returnUrl));

            System.debug('$$$ Signing URL: ' + signingUrl.toExternalForm());

            // Optional: Email the signer or store the URL in a record

        } catch (Exception e) {
            System.debug('### DocuSign Queueable error: ' + e.getMessage());
            System.debug('### Stack trace: ' + e.getStackTraceString());
        }
    }
}