public with sharing class CompletedProcessesCtrl {
    @AuraEnabled(cacheable=true)
    public static List<Process__c> getCompletedProcesses(Id targetObjectId) {
        return [
            SELECT Id, Name, Status__c, StepNumber__c, CreatedDate, ProcessTemplateId__r.Name, Completed_Date__c, Owner.Name, TargetObjectId__c,
                (SELECT Id, Name, Status__c, StepNumber__c, Steps_To_Complete__c, Due_Date__c, Owner.Name, Completed_Date__c
                 FROM ChildProcesses__r
                 ORDER BY StepNumber__c ASC)
            FROM Process__c
            WHERE TargetObjectId__c = :targetObjectId
              AND ParentProcessId__c = null
              AND Status__c = 'Completed'
            ORDER BY CreatedDate DESC
        ];
    }
}