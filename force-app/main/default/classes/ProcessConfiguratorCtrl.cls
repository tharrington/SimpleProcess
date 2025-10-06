public with sharing class ProcessConfiguratorCtrl {

    @AuraEnabled(cacheable=true)
    public static List<Process_Template__c> getTemplates() {
        return [SELECT Id, Name, Steps_To_Complete__c FROM Process_Template__c WHERE Active__c = TRUE ORDER BY Name];
    }

    @AuraEnabled
    public static void updateStepsToComplete(String templateId, String stepsToComplete) {
        Process_Template__c pt = new Process_Template__c(
            Id = templateId,
            Steps_To_Complete__c = stepsToComplete
        );
        update pt;
    }

    @AuraEnabled(cacheable=true)
    public static TemplateDataDTO getTemplateForEditing(Id templateId) {
        Process_Template__c template = [
            SELECT Id, Name, Steps_To_Complete__c FROM Process_Template__c WHERE Id = :templateId
        ];

        List<Related_Process_Template__c> relatedSteps = [
            SELECT Id, StepNumber__c, Sub_Process_Template__c, Sub_Process_Template__r.Name, In_Progress_Requirement__c, Custom_Logic_In_Progress__c
            FROM Related_Process_Template__c
            WHERE Parent_Process_Template__c = :templateId
            ORDER BY StepNumber__c
        ];

        List<StepDTO> steps = new List<StepDTO>();
        for (Related_Process_Template__c r : relatedSteps) {
            steps.add(new StepDTO(
                'step-' + r.StepNumber__c + '__template-' + r.Sub_Process_Template__c,
                'Step ' + r.StepNumber__c + '\n' + r.Sub_Process_Template__r.Name,
                Integer.valueOf(r.StepNumber__c),
                r.Sub_Process_Template__c,
                'step',
                null,
                null,
                null,
                r.In_Progress_Requirement__c,
                r.Custom_Logic_In_Progress__c
            ));
        }

        List<ConnectionDTO> connections = new List<ConnectionDTO>();
        for (Integer i = 0; i < steps.size() - 1; i++) {
            StepDTO fromStep = steps[i];
            StepDTO toStep = steps[i + 1];

            connections.add(new ConnectionDTO(
                fromStep.id,
                toStep.id,
                toStep.templateId
            ));
        }

        TemplateDataDTO result = new TemplateDataDTO();
        result.processName = template.Name;
        result.stepsToComplete = template.Steps_To_Complete__c;
        result.templateId = template.Id;
        result.steps = steps;
        result.connections = connections; 
        return result;
    }

    @AuraEnabled
    public static Id saveProcessTemplate(String payloadJson) {
        if (String.isBlank(payloadJson)) {
            throw new AuraHandledException('Payload is required.');
        }

        PayloadWrapper wrapper;
        try {
            wrapper = (PayloadWrapper) JSON.deserialize(payloadJson, PayloadWrapper.class);
        } catch (Exception e) {
            throw new AuraHandledException('Failed to parse process data: ' + e.getMessage());
        }

        if (String.isBlank(wrapper.processName)) {
            throw new AuraHandledException('Process name is required.');
        }

        Process_Template__c template;
        Boolean isUpdate = !String.isBlank(wrapper.templateId);

        if (isUpdate) {
            template = [SELECT Id, Name FROM Process_Template__c WHERE Id = :wrapper.templateId LIMIT 1];
            template.Name = wrapper.processName;
            template.Steps_To_Complete__c = wrapper.stepsToComplete;
            update template;

            // Delete old related records
            List<Related_Process_Template__c> toDelete = [
                SELECT Id FROM Related_Process_Template__c WHERE Parent_Process_Template__c = :template.Id
            ];
            delete toDelete;
        } else {
            template = new Process_Template__c(
                Name = wrapper.processName,
                Steps_To_Complete__c = wrapper.stepsToComplete,
                Active__c = true,
                Can_Start_Process__c = false
            );
            insert template;
        }

        List<Related_Process_Template__c> relatedRecords = new List<Related_Process_Template__c>();

        for (StepDTO step : wrapper.steps) {
            if (step.type != 'step') continue;
            if (String.isBlank(step.templateId)) continue;

            Related_Process_Template__c record = new Related_Process_Template__c(
                Parent_Process_Template__c = template.Id,
                StepNumber__c = step.stepNumber,
                Sub_Process_Template__c = step.templateId,
                In_Progress_Requirement__c = step.inProgressRequirement,
                Custom_Logic_In_Progress__c = step.customLogic
            );

            relatedRecords.add(record);
        }

        if (!relatedRecords.isEmpty()) {
            insert relatedRecords;
        }

        return template.Id;
    }

    public class PayloadWrapper {
        @AuraEnabled public String processName;
        @AuraEnabled public String stepsToComplete; 
        @AuraEnabled public String templateId;
        @AuraEnabled public List<StepDTO> steps;
        @AuraEnabled public List<ConnectionDTO> connections;

        public PayloadWrapper() {}

        public PayloadWrapper(String processName, String stepsToComplete, String templateId,
                               List<StepDTO> steps, List<ConnectionDTO> connections) {
            this.processName = processName;
            this.stepsToComplete = stepsToComplete;
            this.templateId = templateId;
            this.steps = steps;
            this.connections = connections;
        }
    }

    public class StepDTO {
        @AuraEnabled public String id;
        @AuraEnabled public String label;
        @AuraEnabled public Integer stepNumber;
        @AuraEnabled public String templateId;
        @AuraEnabled public String type;
        @AuraEnabled public String condition;
        @AuraEnabled public Decimal x;
        @AuraEnabled public Decimal y;
        @AuraEnabled public String inProgressRequirement;
        @AuraEnabled public String customLogic;

        public StepDTO() {}

        public StepDTO(String id, String label, Integer stepNumber, String templateId, String type,
                       String condition, Decimal x, Decimal y, String inProgressRequirement, String customLogic) {
            this.id = id;
            this.label = label;
            this.stepNumber = stepNumber;
            this.templateId = templateId;
            this.type = type;
            this.condition = condition;
            this.x = x;
            this.y = y;
            this.inProgressRequirement = inProgressRequirement;
            this.customLogic = customLogic;
        }
    }

    public class ConnectionDTO {
        @AuraEnabled public String fromStep;
        @AuraEnabled public String toStep;
        @AuraEnabled public String toTemplateId;

        public ConnectionDTO() {}

        public ConnectionDTO(String fromStep, String toStep, String toTemplateId) {
            this.fromStep = fromStep;
            this.toStep = toStep;
            this.toTemplateId = toTemplateId;
        }
    }

    public class TemplateDataDTO {
        @AuraEnabled public String processName;
        @AuraEnabled public String stepsToComplete;
        @AuraEnabled public String templateId;
        @AuraEnabled public List<StepDTO> steps;
        @AuraEnabled public List<ConnectionDTO> connections;
    }
}