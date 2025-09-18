public with sharing class DocGenSender {
    public static void sendEnvelope(Id genTemplateId, Id sourceRecordId, Id contactId) {
        Id mySourceId = '500gK00000BNwWQQA1'; // The ID of the initiating Salesforce Opportunity

        // Create an empty envelope
        dfsle.Envelope myEnvelope = dfsle.EnvelopeService.getEmptyEnvelope(
        new dfsle.Entity(mySourceId));
        // The initiating Salesforce entity

        // Add document to the envelope
        Id myDocumentId = '00XXXXXXXXXXXXXXA4'; // The ID of a document stored in a Salesforce library
        Id myFileId = [SELECT id from ContentVersion where ContentDocumentId = :myDocumentId LIMIT 1].id;
        myEnvelope = myEnvelope.withDocuments(dfsle.DocumentService.getDocuments(ContentVersion.getSObjectType(), new Set<Id> { myFileId }));

        //Define a merge field
        //This field will be associated with the initiating source object represented by mySourceId
        dfsle.Tab.MergeField myMergeField = new dfsle.Tab.MergeField (
            'opportunity.name', //The data that this merge field will pull its value from
            null, //N/A
            null, //N/A
            true, //Allows writeback to the Salesforce object
            false //Whether or not the field is read only for the sender
        );

                //Create a text tab that will be mapped to the merge field        
                dfsle.Tab myTextTab = new dfsle.TextTab()
        .withMergeField(myMergeField) //Associate this tab with the mergeField
                    .withReadOnly(false) //true = read only or locked
                    .withPosition(new dfsle.Tab.Position(1, 1, 200, 300, null, null))    
                    .withDataLabel('Contact Name');
    }
}