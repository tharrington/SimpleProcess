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


        List<Related_Process_Template__c> relatedTemplates = [
            SELECT Sub_Process_Template__c, Sub_Process_Template__r.Due_In_Units__c, Sub_Process_Template__r.Due_In_Value__c, 
                Sub_Process_Template__r.Steps_To_Complete__c, StepNumber__c, Sub_Process_Template__r.Name,
                Sub_Process_Template__r.Assigned_User__c, Custom_Logic_In_Progress__c, In_Progress_Requirement__c
            FROM Related_Process_Template__c
            WHERE Parent_Process_Template__c = :templateId AND Sub_Process_Template__r.Active__c = true
            WITH SECURITY_ENFORCED
        ];

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
                ParentProcessId__c = newProcess.Id,
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


        if (!subProcesses.isEmpty()) {
            insert subProcesses;
        }

        return newProcess.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Process__c> getProcessesForTarget(Id targetObjectId) {
        return [
            SELECT Id, Name, ProcessTemplateId__r.Name, ParentProcessId__c, Status__c, CreatedDate, Owner.Name, Due_Date__c, StepNumber__c, Steps_To_Complete__c, In_Progress_Requirement__c, Custom_Logic_In_Progress__c,
                (SELECT Id, Name, ProcessTemplateId__r.Name, Status__c, CreatedDate, Owner.Name, Due_Date__c, StepNumber__c, Steps_To_Complete__c, In_Progress_Requirement__c, Custom_Logic_In_Progress__c
                FROM ChildProcesses__r ORDER BY StepNumber__c ASC)
            FROM Process__c
            WHERE TargetObjectId__c = :targetObjectId AND Status__c != 'Completed'
            ORDER BY CreatedDate ASC
        ];
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
            // ✅ Use getDmlMessage(index) instead of getDmlMessages()
            throw new AuraHandledException(dmlEx.getDmlMessage(0));
        } catch (Exception ex) {
            throw new AuraHandledException('Unexpected error: ' + ex.getMessage());
        }
    }

}