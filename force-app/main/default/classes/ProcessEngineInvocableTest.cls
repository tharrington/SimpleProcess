@isTest
public class ProcessEngineInvocableTest {
    
    @TestSetup
    static void makeData() {
        // Create test Account
        Account testAccount = new Account(
            Name = 'Test Account',
            Type = 'Customer',
            Industry = 'Technology'
        );
        insert testAccount;
        
        // Create a user
        User testUser = TestDataFactory.createStandardUser();
        insert testUser;
        
        // Create process template
        Process_Template__c template = TestDataFactory.createProcessTemplateWithAllFields(
            'Test Template',
            'Test template steps',
            true, // active
            true, // can start process
            testUser.Id,
            1, // due in value
            'Hours' // due in units
        );
        insert template;
        
        // Create multiple process rules to test different operators
        List<Process_Rule__c> rules = new List<Process_Rule__c>();
        rules.add(TestDataFactory.createProcessRule(
            'Name Equals',
            template.Id,
            true,
            'Name',
            'Equals',
            'Test Account',
            1
        ));
        rules.add(TestDataFactory.createProcessRule(
            'Type Contains',
            template.Id,
            true,
            'Type',
            'Contains',
            'Customer',
            2
        ));
        rules.add(TestDataFactory.createProcessRule(
            'Industry Starts With',
            template.Id,
            true,
            'Industry',
            'Starts With',
            'Tech',
            3
        ));
        rules.add(TestDataFactory.createProcessRule(
            'Industry Ends With',
            template.Id,
            true,
            'Industry',
            'Ends With',
            'nology',
            4
        ));
        rules.add(TestDataFactory.createProcessRule(
            'Type Not Equals',
            template.Id,
            true,
            'Type',
            'Not Equals',
            'Prospect',
            5
        ));
        insert rules;
        
        // Create a sub-process template for child process testing
        Process_Template__c subTemplate = TestDataFactory.createProcessTemplateWithAllFields(
            'Sub Process Template',
            'Sub process steps',
            true, // active
            false, // cannot start process independently
            testUser.Id,
            1,
            'Hours'
        );
        insert subTemplate;
        
        // Create related process template to link them
        Related_Process_Template__c relatedTemplate = TestDataFactory.createRelatedProcessTemplate(
            template.Id,
            1, // step number
            subTemplate.Id,
            'Previous Step Completed',
            null
        );
        insert relatedTemplate;
        
        // Add rules for sub-template too
        Process_Rule__c subRule = TestDataFactory.createProcessRule(
            'Sub Rule',
            subTemplate.Id,
            true,
            'Name',
            'Contains',
            'Account',
            1
        );
        insert subRule;
    }
    
    @isTest
    static void testRunProcessEngine_CreateNew() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Process_Template__c template = [SELECT Id FROM Process_Template__c WHERE Name = 'Test Template' LIMIT 1];
        
        // Create request
        ProcessEngineInvocable.Request request = new ProcessEngineInvocable.Request();
        request.processTemplateId = template.Id;
        request.targetRecordId = testAccount.Id;
        request.targetObjectType = 'Account';
        
        Test.startTest();
        
        List<ProcessEngineInvocable.Result> results = ProcessEngineInvocable.runProcessEngine(new List<ProcessEngineInvocable.Request>{request});
        
        Test.stopTest();
        
        // Basic assertions - just verify we got a result
        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0]);
    }
    
    @isTest
    static void testRunProcessEngine_UseExisting() {
        // Get test data
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        Process_Template__c template = [SELECT Id FROM Process_Template__c WHERE Name = 'Test Template' LIMIT 1];
        
        // Create existing process
        Process__c existingProcess = TestDataFactory.createProcessWithAllFields(
            'Existing Process',
            'New',
            0,
            template.Id,
            null, null, null, null,
            null,
            'Test steps',
            testAccount.Id,
            'Account'
        );
        insert existingProcess;
        
        // Create request
        ProcessEngineInvocable.Request request = new ProcessEngineInvocable.Request();
        request.processTemplateId = template.Id;
        request.targetRecordId = testAccount.Id;
        request.targetObjectType = 'Account';
        
        Test.startTest();
        
        List<ProcessEngineInvocable.Result> results = ProcessEngineInvocable.runProcessEngine(new List<ProcessEngineInvocable.Request>{request});
        
        Test.stopTest();
        
        // Basic assertions - just verify we got a result
        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0]);
    }
}

