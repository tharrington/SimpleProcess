@isTest
public class TestDataFactory {
    
    // Process Template Constants
    public static final String ACTIVE_TEMPLATE_NAME = 'Test Active Template';
    public static final String INACTIVE_TEMPLATE_NAME = 'Test Inactive Template';
    public static final String ANOTHER_ACTIVE_TEMPLATE_NAME = 'Another Active Template';
    public static final String SUB_PROCESS_1_NAME = 'Sub Process 1';
    public static final String SUB_PROCESS_2_NAME = 'Sub Process 2';
    
    // Process Constants
    public static final String PROCESS_NAME_PREFIX = 'Test Process';
    
    // Process Rule Constants
    public static final String DEFAULT_FIELD_NAME = 'Test_Field__c';
    public static final String DEFAULT_OPERATOR = 'contains';
    public static final String DEFAULT_VALUE = 'Test Value';
    
    /**
     * Creates a complete test data setup including templates and related process templates
     */
    public static TestDataResult createCompleteTestData() {
        List<Process_Template__c> templates = createProcessTemplates();
        insert templates;
        
        Map<String, Process_Template__c> templateMap = new Map<String, Process_Template__c>();
        for (Process_Template__c template : templates) {
            templateMap.put(template.Name, template);
        }
        
        List<Related_Process_Template__c> relatedTemplates = createRelatedProcessTemplates(templateMap);
        insert relatedTemplates;
        
        return new TestDataResult(templateMap, relatedTemplates);
    }
    
    /**
     * Creates basic process templates without inserting them
     */
    public static List<Process_Template__c> createProcessTemplates() {
        List<Process_Template__c> templates = new List<Process_Template__c>();
        
        // Active main template
        templates.add(createProcessTemplate(
            ACTIVE_TEMPLATE_NAME,
            '3',
            true,
            false
        ));
        
        // Inactive template (should not be returned by getTemplates)
        templates.add(createProcessTemplate(
            INACTIVE_TEMPLATE_NAME,
            '2',
            false,
            false
        ));
        
        // Another active template
        templates.add(createProcessTemplate(
            ANOTHER_ACTIVE_TEMPLATE_NAME,
            '5',
            true,
            true
        ));
        
        // Sub-process templates for related steps
        templates.add(createProcessTemplate(
            SUB_PROCESS_1_NAME,
            '1',
            true,
            false
        ));
        
        templates.add(createProcessTemplate(
            SUB_PROCESS_2_NAME,
            '2',
            true,
            false
        ));
        
        return templates;
    }
    
    /**
     * Creates a single Process Template with specified parameters
     */
    public static Process_Template__c createProcessTemplate(String name, String stepsToComplete, Boolean active, Boolean canStartProcess) {
        return new Process_Template__c(
            Name = name,
            Steps_To_Complete__c = stepsToComplete,
            Active__c = active,
            Can_Start_Process__c = canStartProcess
        );
    }
    
    /**
     * Creates a Process Template with all optional fields
     */
    public static Process_Template__c createProcessTemplateWithAllFields(
        String name, 
        String stepsToComplete, 
        Boolean active, 
        Boolean canStartProcess,
        Id assignedUserId,
        Decimal dueInValue,
        String dueInUnits,
        String fieldName,
        String operator,
        String value,
        Id parentProcessTemplateId
    ) {
        return new Process_Template__c(
            Name = name,
            Steps_To_Complete__c = stepsToComplete,
            Active__c = active,
            Can_Start_Process__c = canStartProcess,
            Assigned_User__c = assignedUserId,
            Due_In_Value__c = dueInValue,
            Due_In_Units__c = dueInUnits,
            FieldName__c = fieldName,
            Operator__c = operator,
            Value__c = value,
            ParentProcessTemplateId__c = parentProcessTemplateId
        );
    }
    
    /**
     * Creates related process templates for the main active template
     */
    public static List<Related_Process_Template__c> createRelatedProcessTemplates(Map<String, Process_Template__c> templateMap) {
        List<Related_Process_Template__c> relatedTemplates = new List<Related_Process_Template__c>();
        
        Process_Template__c parentTemplate = templateMap.get(ACTIVE_TEMPLATE_NAME);
        Process_Template__c subProcess1 = templateMap.get(SUB_PROCESS_1_NAME);
        Process_Template__c subProcess2 = templateMap.get(SUB_PROCESS_2_NAME);
        
        relatedTemplates.add(createRelatedProcessTemplate(
            parentTemplate.Id,
            1,
            subProcess1.Id,
            'Previous Step Completed',
            'Custom Logic 1'
        ));
        
        relatedTemplates.add(createRelatedProcessTemplate(
            parentTemplate.Id,
            2,
            subProcess2.Id,
            'Custom Logic',
            'Custom Logic 2'
        ));
        
        return relatedTemplates;
    }
    
    /**
     * Creates a single Related Process Template with specified parameters
     */
    public static Related_Process_Template__c createRelatedProcessTemplate(
        Id parentTemplateId, 
        Decimal stepNumber, 
        Id subProcessTemplateId,
        String inProgressRequirement,
        String customLogic
    ) {
        return new Related_Process_Template__c(
            Parent_Process_Template__c = parentTemplateId,
            StepNumber__c = stepNumber,
            Sub_Process_Template__c = subProcessTemplateId,
            In_Progress_Requirement__c = inProgressRequirement,
            Custom_Logic_In_Progress__c = customLogic
        );
    }
    
    /**
     * Creates a Process record
     */
    public static Process__c createProcess(
        String name,
        String status,
        Decimal stepNumber,
        Id processTemplateId
    ) {
        return new Process__c(
            Name = name,
            Status__c = status,
            StepNumber__c = stepNumber,
            ProcessTemplateId__c = processTemplateId
        );
    }
    
    /**
     * Creates a Process record with all fields
     */
    public static Process__c createProcessWithAllFields(
        String name,
        String status,
        Decimal stepNumber,
        Id processTemplateId,
        DateTime completedDate,
        String customLogicInProgress,
        DateTime dueDate,
        String inProgressRequirement,
        Id parentProcessId,
        String stepsToComplete,
        String targetObjectId,
        String targetObjectType
    ) {
        return new Process__c(
            Name = name,
            Status__c = status,
            StepNumber__c = stepNumber,
            ProcessTemplateId__c = processTemplateId,
            Completed_Date__c = completedDate,
            Custom_Logic_In_Progress__c = customLogicInProgress,
            Due_Date__c = dueDate,
            In_Progress_Requirement__c = inProgressRequirement,
            ParentProcessId__c = parentProcessId,
            Steps_To_Complete__c = stepsToComplete,
            TargetObjectId__c = targetObjectId,
            TargetObjectType__c = targetObjectType
        );
    }
    
    /**
     * Creates a Process Rule record
     */
    public static Process_Rule__c createProcessRule(
        String name,
        Id processTemplateId,
        Boolean active,
        String fieldName,
        String operator,
        String value,
        Decimal order
    ) {
        return new Process_Rule__c(
            Name = name,
            ProcessTemplate__c = processTemplateId,
            Active__c = active,
            FieldName__c = fieldName,
            Operator__c = operator,
            Value__c = value,
            Order__c = order
        );
    }
    
    /**
     * Creates multiple Process records for testing
     */
    public static List<Process__c> createProcesses(Integer count, Id processTemplateId) {
        List<Process__c> processes = new List<Process__c>();
        
        for (Integer i = 1; i <= count; i++) {
            processes.add(createProcess(
                PROCESS_NAME_PREFIX + ' ' + i,
                'New',
                i,
                processTemplateId
            ));
        }
        
        return processes;
    }
    
    /**
     * Creates multiple Process Rule records for testing
     */
    public static List<Process_Rule__c> createProcessRules(Integer count, Id processTemplateId) {
        List<Process_Rule__c> processRules = new List<Process_Rule__c>();
        
        for (Integer i = 1; i <= count; i++) {
            processRules.add(createProcessRule(
                'Test Rule ' + i,
                processTemplateId,
                true,
                DEFAULT_FIELD_NAME + i,
                DEFAULT_OPERATOR,
                DEFAULT_VALUE + ' ' + i,
                i
            ));
        }
        
        return processRules;
    }
    
    // ProcessConfigurator specific methods
    /**
     * Creates a PayloadWrapper for testing saveProcessTemplate method
     */
    public static ProcessConfiguratorCtrl.PayloadWrapper createPayloadWrapper(
        String processName,
        String stepsToComplete,
        String templateId,
        List<ProcessConfiguratorCtrl.StepDTO> steps,
        List<ProcessConfiguratorCtrl.ConnectionDTO> connections
    ) {
        return new ProcessConfiguratorCtrl.PayloadWrapper(
            processName,
            stepsToComplete,
            templateId,
            steps,
            connections
        );
    }
    
    /**
     * Creates a StepDTO for testing
     */
    public static ProcessConfiguratorCtrl.StepDTO createStepDTO(
        String id,
        String label,
        Integer stepNumber,
        String templateId,
        String type,
        String inProgressRequirement,
        String customLogic
    ) {
        return new ProcessConfiguratorCtrl.StepDTO(
            id,
            label,
            stepNumber,
            templateId,
            type,
            null, // condition
            null, // x
            null, // y
            inProgressRequirement,
            customLogic
        );
    }
    
    /**
     * Creates a ConnectionDTO for testing
     */
    public static ProcessConfiguratorCtrl.ConnectionDTO createConnectionDTO(
        String fromStep,
        String toStep,
        String toTemplateId
    ) {
        return new ProcessConfiguratorCtrl.ConnectionDTO(fromStep, toStep, toTemplateId);
    }
    
    /**
     * Creates a step DTO for a new process template test
     */
    public static ProcessConfiguratorCtrl.StepDTO createNewProcessStepDTO(Id subProcessId) {
        return createStepDTO(
            'step-1__template-' + subProcessId,
            'Step 1\nSub Process 1',
            1,
            subProcessId,
            'step',
            'Previous Step Completed',
            'Test Custom Logic'
        );
    }
    
    /**
     * Creates a step DTO for updating an existing process template
     */
    public static ProcessConfiguratorCtrl.StepDTO createUpdateProcessStepDTO(Id subProcessId) {
        return createStepDTO(
            'step-1__template-' + subProcessId,
            'Step 1\nSub Process 2',
            1,
            subProcessId,
            'step',
            'Custom Logic',
            'Updated Custom Logic'
        );
    }
    
    /**
     * Creates a non-step type DTO for testing filtering
     */
    public static ProcessConfiguratorCtrl.StepDTO createNonStepDTO() {
        return createStepDTO(
            'decision-1',
            'Decision Point',
            1,
            null,
            'decision', // non-step type
            null,
            null
        );
    }
    
    /**
     * Creates a step DTO with blank template ID for testing filtering
     */
    public static ProcessConfiguratorCtrl.StepDTO createBlankTemplateIdStepDTO() {
        return createStepDTO(
            'step-1',
            'Step with blank template ID',
            1,
            '', // blank template ID
            'step',
            'Previous Step Completed',
            'Test Logic'
        );
    }
    
    /**
     * Wrapper class to return test data results
     */
    public class TestDataResult {
        public Map<String, Process_Template__c> templateMap;
        public List<Related_Process_Template__c> relatedTemplates;
        
        public TestDataResult(Map<String, Process_Template__c> templateMap, List<Related_Process_Template__c> relatedTemplates) {
            this.templateMap = templateMap;
            this.relatedTemplates = relatedTemplates;
        }
        
        public Process_Template__c getTemplate(String name) {
            return templateMap.get(name);
        }
        
        public Id getTemplateId(String name) {
            Process_Template__c template = templateMap.get(name);
            return template != null ? template.Id : null;
        }
    }
    
    /**
     * Utility method to create a test user
     */
    public static User createTestUser(String profileName) {
        Profile profile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        
        return new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser@example.com.' + DateTime.now().getTime(),
            Alias = 'tuser',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = profile.Id
        );
    }
    
    /**
     * Utility method to create a standard test user
     */
    public static User createStandardUser() {
        return createTestUser('Standard User');
    }
}