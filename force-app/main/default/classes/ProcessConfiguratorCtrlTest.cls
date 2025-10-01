@isTest
public class ProcessConfiguratorCtrlTest {
    
    @TestSetup
    static void makeData() {
        TestDataFactory.createCompleteTestData();
    }
    
    @isTest
    static void testGetTemplates() {
        Test.startTest();
        List<Process_Template__c> result = ProcessConfiguratorCtrl.getTemplates();
        Test.stopTest();
        
        // Should return only active templates, ordered by Name
        System.assertEquals(4, result.size(), 'Should return 4 active templates (including sub-processes)');
        
        // Verify ordering by Name
        System.assertEquals(TestDataFactory.ANOTHER_ACTIVE_TEMPLATE_NAME, result[0].Name);
        System.assertEquals(TestDataFactory.SUB_PROCESS_1_NAME, result[1].Name);
        System.assertEquals(TestDataFactory.SUB_PROCESS_2_NAME, result[2].Name);
        System.assertEquals(TestDataFactory.ACTIVE_TEMPLATE_NAME, result[3].Name);
        
        // Verify all returned templates are active
        for (Process_Template__c template : result) {
            System.assertNotEquals(null, template.Id);
            System.assertNotEquals(null, template.Name);
            System.assertNotEquals(null, template.Steps_To_Complete__c);
        }
    }
    
    @isTest
    static void testUpdateStepsToComplete() {
        Process_Template__c template = [SELECT Id FROM Process_Template__c WHERE Name = :TestDataFactory.ACTIVE_TEMPLATE_NAME LIMIT 1];
        String newStepsToComplete = '10';
        
        Test.startTest();
        ProcessConfiguratorCtrl.updateStepsToComplete(template.Id, newStepsToComplete);
        Test.stopTest();
        
        // Verify the update
        Process_Template__c updatedTemplate = [SELECT Steps_To_Complete__c FROM Process_Template__c WHERE Id = :template.Id];
        System.assertEquals(newStepsToComplete, updatedTemplate.Steps_To_Complete__c);
    }
    
    @isTest
    static void testGetTemplateForEditing() {
        Process_Template__c template = [SELECT Id FROM Process_Template__c WHERE Name = :TestDataFactory.ACTIVE_TEMPLATE_NAME LIMIT 1];
        
        Test.startTest();
        ProcessConfiguratorCtrl.TemplateDataDTO result = ProcessConfiguratorCtrl.getTemplateForEditing(template.Id);
        Test.stopTest();
        
        // Verify template data
        System.assertEquals(TestDataFactory.ACTIVE_TEMPLATE_NAME, result.processName);
        System.assertEquals(template.Id, result.templateId);
        
        // Verify steps
        System.assertEquals(2, result.steps.size());
        
        ProcessConfiguratorCtrl.StepDTO step1 = result.steps[0];
        System.assertEquals(1, step1.stepNumber);
        System.assertEquals('step', step1.type);
        System.assert(step1.label.contains('Step 1'));
        System.assert(step1.label.contains(TestDataFactory.SUB_PROCESS_1_NAME));
        
        ProcessConfiguratorCtrl.StepDTO step2 = result.steps[1];
        System.assertEquals(2, step2.stepNumber);
        
        // Verify connections (should be 1 connection between step 1 and step 2)
        System.assertEquals(1, result.connections.size());
        ProcessConfiguratorCtrl.ConnectionDTO connection = result.connections[0];
        System.assertEquals(step1.id, connection.fromStep);
        System.assertEquals(step2.id, connection.toStep);
        System.assertEquals(step2.templateId, connection.toTemplateId);
    }
    
    @isTest
    static void testSaveProcessTemplate_NewTemplate() {
        Process_Template__c subProcess = [SELECT Id FROM Process_Template__c WHERE Name = :TestDataFactory.SUB_PROCESS_1_NAME LIMIT 1];
        
        // Create payload for new template
        List<ProcessConfiguratorCtrl.StepDTO> steps = new List<ProcessConfiguratorCtrl.StepDTO>();
        steps.add(TestDataFactory.createNewProcessStepDTO(subProcess.Id));
        
        List<ProcessConfiguratorCtrl.ConnectionDTO> connections = new List<ProcessConfiguratorCtrl.ConnectionDTO>();
        
        ProcessConfiguratorCtrl.PayloadWrapper payload = TestDataFactory.createPayloadWrapper(
            'New Test Process',
            '5',
            null, // null templateId indicates new template
            steps,
            connections
        );
        
        String payloadJson = JSON.serialize(payload);
        
        Test.startTest();
        Id newTemplateId = ProcessConfiguratorCtrl.saveProcessTemplate(payloadJson);
        Test.stopTest();
        
        // Verify new template was created
        System.assertNotEquals(null, newTemplateId);
        
        Process_Template__c newTemplate = [SELECT Name, Steps_To_Complete__c, Active__c, Can_Start_Process__c 
                                          FROM Process_Template__c WHERE Id = :newTemplateId];
        System.assertEquals('New Test Process', newTemplate.Name);
        System.assertEquals('5', newTemplate.Steps_To_Complete__c);
        System.assertEquals(true, newTemplate.Active__c);
        System.assertEquals(false, newTemplate.Can_Start_Process__c);
        
        // Verify related template was created
        List<Related_Process_Template__c> relatedTemplates = [
            SELECT StepNumber__c, Sub_Process_Template__c, In_Progress_Requirement__c, Custom_Logic_In_Progress__c
            FROM Related_Process_Template__c 
            WHERE Parent_Process_Template__c = :newTemplateId
        ];
        System.assertEquals(1, relatedTemplates.size());
        System.assertEquals(1, relatedTemplates[0].StepNumber__c);
        System.assertEquals(subProcess.Id, relatedTemplates[0].Sub_Process_Template__c);
    }
    
    
    
    @isTest
    static void testSaveProcessTemplate_WithNonStepTypes() {
        // Test that non-step types are filtered out
        List<ProcessConfiguratorCtrl.StepDTO> steps = new List<ProcessConfiguratorCtrl.StepDTO>();
        
        // Add a non-step type (should be filtered out)
        steps.add(TestDataFactory.createNonStepDTO());
        
        ProcessConfiguratorCtrl.PayloadWrapper payload = TestDataFactory.createPayloadWrapper(
            'Test Process with Non-Steps',
            '3',
            null,
            steps,
            new List<ProcessConfiguratorCtrl.ConnectionDTO>()
        );
        
        Test.startTest();
        Id newTemplateId = ProcessConfiguratorCtrl.saveProcessTemplate(JSON.serialize(payload));
        Test.stopTest();
        
        // Verify template was created but no related templates (since non-step types are filtered)
        System.assertNotEquals(null, newTemplateId);
        
        List<Related_Process_Template__c> relatedTemplates = [
            SELECT Id FROM Related_Process_Template__c WHERE Parent_Process_Template__c = :newTemplateId
        ];
        System.assertEquals(0, relatedTemplates.size(), 'No related templates should be created for non-step types');
    }
    
    @isTest
    static void testSaveProcessTemplate_WithBlankTemplateIds() {
        // Test that steps with blank template IDs are filtered out
        List<ProcessConfiguratorCtrl.StepDTO> steps = new List<ProcessConfiguratorCtrl.StepDTO>();
        
        steps.add(TestDataFactory.createBlankTemplateIdStepDTO());
        
        ProcessConfiguratorCtrl.PayloadWrapper payload = TestDataFactory.createPayloadWrapper(
            'Test Process with Blank Template IDs',
            '2',
            null,
            steps,
            new List<ProcessConfiguratorCtrl.ConnectionDTO>()
        );
        
        Test.startTest();
        Id newTemplateId = ProcessConfiguratorCtrl.saveProcessTemplate(JSON.serialize(payload));
        Test.stopTest();
        
        // Verify template was created but no related templates (since template ID is blank)
        System.assertNotEquals(null, newTemplateId);
        
        List<Related_Process_Template__c> relatedTemplates = [
            SELECT Id FROM Related_Process_Template__c WHERE Parent_Process_Template__c = :newTemplateId
        ];
        System.assertEquals(0, relatedTemplates.size(), 'No related templates should be created for steps with blank template IDs');
    }
}