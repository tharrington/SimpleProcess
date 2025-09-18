trigger ProcessTrigger on Process__c (
    before insert, before update, before delete,
    after insert, after update, after delete
) {
    ITriggerHandler handler = TriggerHandlerFactory.getHandler('Process__c');
    handler.handle(TriggerContext.fromTrigger());
}
