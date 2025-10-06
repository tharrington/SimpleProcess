public class ProcessEngineInvocable {
    
    @InvocableMethod(
        label='Run Process Engine'
        description='Executes process rules for a given Process record'
        category='Simple Process'
    )
    public static List<Result> runProcessEngine(List<Request> requests) {
        List<Result> results = new List<Result>();
        
        for (Request request : requests) {
            Result result = new Result();
            try {
                // Find or create the Process record
                Process__c process = getOrCreateProcess(
                    request.processTemplateId,
                    request.targetRecordId,
                    request.targetObjectType
                );
                
                // Run the process engine
                ProcessEngine.run(process);
                
                result.success = true;
                result.processId = process.Id;
                result.message = 'Process executed successfully';
                
            } catch (Exception e) {
                result.success = false;
                result.message = e.getMessage();
                result.errorType = e.getTypeName();
            }
            
            results.add(result);
        }
        
        return results;
    }
    
    private static Process__c getOrCreateProcess(
        Id processTemplateId,
        Id targetRecordId,
        String targetObjectType
    ) {
        // Check if Process already exists
        List<Process__c> existingProcesses = [
            SELECT Id
            FROM Process__c
            WHERE ProcessTemplateId__c = :processTemplateId
            AND TargetObjectId__c = :targetRecordId
            LIMIT 1
        ];
        
        if (!existingProcesses.isEmpty()) {
            return existingProcesses[0];
        }
        
        // Create new Process record
        Process__c process = new Process__c(
            ProcessTemplateId__c = processTemplateId,
            TargetObjectId__c = targetRecordId,
            TargetObjectType__c = targetObjectType,
            Status__c = 'In Progress' // Adjust based on your fields
        );
        
        insert process;
        return process;
    }
    
    // Input parameters for the invocable method
    public class Request {
        @InvocableVariable(
            label='Process Template ID'
            description='ID of the Process Template to use'
            required=true
        )
        public Id processTemplateId;
        
        @InvocableVariable(
            label='Target Record ID'
            description='ID of the record to enroll in the process'
            required=true
        )
        public Id targetRecordId;
        
        @InvocableVariable(
            label='Target Object Type'
            description='API name of the target object (e.g., Account, Opportunity)'
            required=true
        )
        public String targetObjectType;
    }
    
    // Output parameters from the invocable method
    public class Result {
        @InvocableVariable(label='Success')
        public Boolean success;
        
        @InvocableVariable(label='Process ID')
        public Id processId;
        
        @InvocableVariable(label='Message')
        public String message;
        
        @InvocableVariable(label='Error Type')
        public String errorType;
    }
}