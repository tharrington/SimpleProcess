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
                // Check if Process already exists for this template and target
                List<Process__c> existingProcesses = [
                    SELECT Id
                    FROM Process__c
                    WHERE ProcessTemplateId__c = :request.processTemplateId
                    AND TargetObjectId__c = :request.targetRecordId
                    LIMIT 1
                ];
                
                Id processId;
                
                if (!existingProcesses.isEmpty()) {
                    // Use existing process
                    processId = existingProcesses[0].Id;
                    result.message = 'Using existing process';
                } else {
                    // Create new process with all children using the existing method
                    processId = ProcessStepCtrl.createProcessFromTemplate(
                        request.processTemplateId,
                        request.targetRecordId,
                        request.targetObjectType
                    );
                    result.message = 'Process created successfully with all child processes';
                }
                
                // Run the process engine on the top-level process
                Process__c process = [SELECT Id FROM Process__c WHERE Id = :processId LIMIT 1];
                ProcessEngine.run(process);
                
                result.success = true;
                result.processId = processId;
                
            } catch (Exception e) {
                result.success = false;
                result.message = e.getMessage();
                result.errorType = e.getTypeName();
            }
            
            results.add(result);
        }
        
        return results;
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