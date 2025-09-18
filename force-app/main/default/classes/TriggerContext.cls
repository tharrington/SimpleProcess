public class TriggerContext {
    public Boolean isBefore { get; private set; }
    public Boolean isAfter { get; private set; }
    public Boolean isInsert { get; private set; }
    public Boolean isUpdate { get; private set; }
    public Boolean isDelete { get; private set; }
    public Boolean isUndelete { get; private set; }
    public Boolean isExecuting { get; private set; }

    public List<sObject> newRecords { get; private set; }
    public List<sObject> oldRecords { get; private set; }
    public Map<Id, sObject> newMap { get; private set; }
    public Map<Id, sObject> oldMap { get; private set; }

    private TriggerContext() {}

    public static TriggerContext fromTrigger() {
        TriggerContext ctx = new TriggerContext();
        ctx.isBefore = Trigger.isBefore;
        ctx.isAfter = Trigger.isAfter;
        ctx.isInsert = Trigger.isInsert;
        ctx.isUpdate = Trigger.isUpdate;
        ctx.isDelete = Trigger.isDelete;
        ctx.isUndelete = Trigger.isUndelete;
        ctx.isExecuting = Trigger.isExecuting;

        ctx.newRecords = Trigger.isInsert || Trigger.isUpdate ? Trigger.new : null;
        ctx.oldRecords = Trigger.isUpdate || Trigger.isDelete ? Trigger.old : null;
        ctx.newMap = Trigger.isInsert || Trigger.isUpdate ? Trigger.newMap : null;
        ctx.oldMap = Trigger.isUpdate || Trigger.isDelete ? Trigger.oldMap : null;

        return ctx;
    }
}