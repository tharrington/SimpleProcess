public with sharing class ProcessStepCtrl {
    @AuraEnabled(cacheable=true)
    public static List<Process_Template__c> getTemplates() {
        return [SELECT Id, Name FROM Process_Template__c WHERE Active__c = TRUE AND Can_Start_Process__c = true ORDER BY Name];
    }

    @AuraEnabled
    public static Id createProcessFromTemplate(Id templateId, Id targetObjectId, String targetObjectType) {
        // Query the template name
        Process_Template__c template = [
            SELECT Name
            FROM Process_Template__c
            WHERE Id = :templateId
            LIMIT 1
        ];

        // Create main process with name from template
        Process__c newProcess = new Process__c(
            Name = template.Name,
            ProcessTemplateId__c = templateId,
            Status__c = 'New',
            StepNumber__c = 0,
            TargetObjectId__c = targetObjectId,
            TargetObjectType__c = targetObjectType
        );
        insert newProcess;

        // Create child processes recursively
        createChildProcesses(newProcess.Id, templateId, targetObjectId, targetObjectType);

        return newProcess.Id;
    }

    private static void createChildProcesses(Id parentProcessId, Id parentTemplateId, Id targetObjectId, String targetObjectType) {
        List<Related_Process_Template__c> relatedTemplates = [
            SELECT Sub_Process_Template__c, Sub_Process_Template__r.Due_In_Units__c, Sub_Process_Template__r.Due_In_Value__c, 
                Sub_Process_Template__r.Steps_To_Complete__c, StepNumber__c, Sub_Process_Template__r.Name,
                Sub_Process_Template__r.Assigned_User__c, Custom_Logic_In_Progress__c, In_Progress_Requirement__c
            FROM Related_Process_Template__c
            WHERE Parent_Process_Template__c = :parentTemplateId AND Sub_Process_Template__r.Active__c = true
            ORDER BY StepNumber__c ASC
        ];

        if (relatedTemplates.isEmpty()) {
            return;
        }

        List<Process__c> subProcesses = new List<Process__c>();
        for (Related_Process_Template__c rel : relatedTemplates) {
            DateTime dueDate;
            Integer offset = rel.Sub_Process_Template__r.Due_In_Value__c != null ? 
                Integer.valueOf(rel.Sub_Process_Template__r.Due_In_Value__c) : 0;

            String units = rel.Sub_Process_Template__r.Due_In_Units__c;

            if (units == 'Minutes') {
                dueDate = System.now().addMinutes(offset);
            } else if (units == 'Hours') {
                dueDate = System.now().addHours(offset);
            } else if (units == 'Days') {
                dueDate = System.now().addDays(offset);
            } else {
                dueDate = System.now(); 
            }

            subProcesses.add(new Process__c(
                Name = rel.Sub_Process_Template__r.Name,
                ProcessTemplateId__c = rel.Sub_Process_Template__c,
                ParentProcessId__c = parentProcessId,
                Status__c = 'New',
                Steps_To_Complete__c = rel.Sub_Process_Template__r.Steps_To_Complete__c,
                Due_Date__c = dueDate,
                In_Progress_Requirement__c = rel.In_Progress_Requirement__c,
                Custom_Logic_In_Progress__c = rel.Custom_Logic_In_Progress__c,
                StepNumber__c = rel.StepNumber__c,
                TargetObjectId__c = targetObjectId,
                OwnerId = rel.Sub_Process_Template__r.Assigned_User__c,
                TargetObjectType__c = targetObjectType
            ));
        }

        insert subProcesses;

        // Recursively create children for each subprocess
        for (Process__c subProcess : subProcesses) {
            createChildProcesses(subProcess.Id, subProcess.ProcessTemplateId__c, targetObjectId, targetObjectType);
        }
    }

    @AuraEnabled
    public static void updateProcessStatus(Id processId, String newStatus) {
        try {
            List<Process__c> processes = [
                SELECT Id, Status__c
                FROM Process__c
                WHERE Id = :processId
                WITH SECURITY_ENFORCED
            ];

            if (processes.isEmpty()) {
                throw new AuraHandledException('Process record not found.');
            }

            Process__c process = processes[0];
            process.Status__c = newStatus;

            update process;

        } catch (DmlException dmlEx) {
            throw new AuraHandledException(dmlEx.getDmlMessage(0));
        } catch (Exception ex) {
            throw new AuraHandledException('Unexpected error: ' + ex.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ProcessWrapper> getProcessesForTarget(Id targetObjectId) {
        List<Process__c> topLevelProcesses = [
            SELECT Id, Name, ProcessTemplateId__c, ProcessTemplateId__r.Name, ParentProcessId__c, 
                Status__c, CreatedDate, Owner.Name, Due_Date__c, StepNumber__c, 
                Steps_To_Complete__c, In_Progress_Requirement__c, Custom_Logic_In_Progress__c
            FROM Process__c
            WHERE TargetObjectId__c = :targetObjectId 
            AND ParentProcessId__c = NULL 
            AND Status__c != 'Completed'
            ORDER BY CreatedDate ASC
        ];
        
        List<ProcessWrapper> result = new List<ProcessWrapper>();
        for (Process__c proc : topLevelProcesses) {
            result.add(buildProcessWrapper(proc, targetObjectId));
        }
        
        return result;
    }

    private static ProcessWrapper buildProcessWrapper(Process__c proc, Id targetObjectId) {
        ProcessWrapper wrapper = new ProcessWrapper();
        wrapper.Id = proc.Id;
        wrapper.Name = proc.Name;
        
        // Add null check for ProcessTemplateId relationship
        if (proc.ProcessTemplateId__r != null) {
            wrapper.ProcessTemplateId = new ProcessTemplateRelation();
            wrapper.ProcessTemplateId.Name = proc.ProcessTemplateId__r.Name;
        }
        
        wrapper.Status = proc.Status__c;
        wrapper.CreatedDate = proc.CreatedDate;
        
        // Add null check for Owner relationship
        if (proc.Owner != null) {
            wrapper.Owner = new OwnerRelation();
            wrapper.Owner.Name = proc.Owner.Name;
        }
        
        wrapper.Due_Date = proc.Due_Date__c;
        wrapper.StepNumber = proc.StepNumber__c;
        wrapper.Steps_To_Complete = proc.Steps_To_Complete__c;
        wrapper.In_Progress_Requirement = proc.In_Progress_Requirement__c;
        wrapper.Custom_Logic_In_Progress = proc.Custom_Logic_In_Progress__c;
        
        // Query children and recursively build their wrappers
        List<Process__c> children = [
            SELECT Id, Name, ProcessTemplateId__c, ProcessTemplateId__r.Name, ParentProcessId__c, 
                Status__c, CreatedDate, Owner.Name, Due_Date__c, StepNumber__c, 
                Steps_To_Complete__c, In_Progress_Requirement__c, Custom_Logic_In_Progress__c
            FROM Process__c
            WHERE ParentProcessId__c = :proc.Id
            ORDER BY StepNumber__c ASC
        ];
        
        wrapper.children = new List<ProcessWrapper>();
        for (Process__c child : children) {
            wrapper.children.add(buildProcessWrapper(child, targetObjectId));
        }
        
        return wrapper;
    }

    // Wrapper classes for JSON serialization
    public class ProcessWrapper {
        @AuraEnabled public Id Id { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public ProcessTemplateRelation ProcessTemplateId { get; set; }
        @AuraEnabled public String Status { get; set; }
        @AuraEnabled public DateTime CreatedDate { get; set; }
        @AuraEnabled public OwnerRelation Owner { get; set; }
        @AuraEnabled public DateTime Due_Date { get; set; }
        @AuraEnabled public Decimal StepNumber { get; set; }
        @AuraEnabled public String Steps_To_Complete { get; set; }
        @AuraEnabled public String In_Progress_Requirement { get; set; }
        @AuraEnabled public String Custom_Logic_In_Progress { get; set; }
        @AuraEnabled public List<ProcessWrapper> children { get; set; }
    }

    public class ProcessTemplateRelation {
        @AuraEnabled public String Name { get; set; }
    }

    public class OwnerRelation {
        @AuraEnabled public String Name { get; set; }
    }
}