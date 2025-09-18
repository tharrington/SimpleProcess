public with sharing class EmbeddedSigningController {
    @AuraEnabled
    public static String createEnvelopeAsync(
        String contactId,
        String roleName,
        String returnUrl,
        String onboardingDocId,
        String contentVersionId
    ) {
        Contact contact = [
            SELECT Id, Name, Email
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        ContentVersion cv = [
            SELECT Id, Title, FileExtension, VersionData
            FROM ContentVersion
            WHERE Id = :contentVersionId
            LIMIT 1
        ];

        dfsle.Document doc = dfsle.Document.fromFile(cv);

        dfsle.Recipient signer = dfsle.Recipient.newEmbeddedSigner();

        dfsle.Envelope envelope = dfsle.EnvelopeService.getEmptyEnvelope(
            new dfsle.Entity(onboardingDocId)
        );
        envelope = envelope
            .withDocuments(new List<dfsle.Document>{ doc })
            .withRecipients(new List<dfsle.Recipient>{ signer });

        envelope = dfsle.EnvelopeService.sendEnvelope(envelope, true);
        System.debug('#### env: ' + envelope);
        return String.valueOf(envelope.docuSignId);
    }

    @AuraEnabled
    public static String getSenderViewUrl(String docuSignId, String returnUrl) {
        dfsle.UUID envUUID = dfsle.UUID.parse(docuSignId);


        return dfsle.SigningService.getEmbeddedSigningUrl(
            envUUID,
            new Url(returnUrl)
        ).toExternalForm();
    }
}
