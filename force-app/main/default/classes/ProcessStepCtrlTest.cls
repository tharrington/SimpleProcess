@isTest
public class ProcessStepCtrlTest {
    
    @TestSetup
    static void makeData() {
        // Create a user to assign to templates
        User testUser = TestDataFactory.createStandardUser();
        insert testUser;
        
        // Create main process template that can start a process
        Process_Template__c mainTemplate = TestDataFactory.createProcessTemplateWithAllFields(
            'Main Process Template',
            'Main process steps',
            true, // active
            true, // can start process
            testUser.Id, // assigned user
            1, // due in value
            'Hours' // due in units
        );
        insert mainTemplate;
        
        // Create sub-process templates
        List<Process_Template__c> subTemplates = new List<Process_Template__c>();
        subTemplates.add(TestDataFactory.createProcessTemplateWithAllFields(
            'Sub Process 1',
            'Sub process 1 steps',
            true, // active
            false, // cannot start process
            testUser.Id,
            2, // due in 2 hours
            'Hours'
        ));
        subTemplates.add(TestDataFactory.createProcessTemplateWithAllFields(
            'Sub Process 2',
            'Sub process 2 steps',
            true, // active
            false, // cannot start process
            testUser.Id,
            1, // due in 1 day
            'Days'
        ));
        insert subTemplates;
        
        // Create related process templates (linking main to sub processes)
        List<Related_Process_Template__c> relatedTemplates = new List<Related_Process_Template__c>();
        relatedTemplates.add(TestDataFactory.createRelatedProcessTemplate(
            mainTemplate.Id,
            1, // step number
            subTemplates[0].Id,
            'Previous Step Completed',
            null
        ));
        relatedTemplates.add(TestDataFactory.createRelatedProcessTemplate(
            mainTemplate.Id,
            2, // step number
            subTemplates[1].Id,
            'Custom Logic',
            '1' // simple custom logic
        ));
        insert relatedTemplates;
        
        // Create an inactive template (should not appear in getTemplates)
        Process_Template__c inactiveTemplate = TestDataFactory.createProcessTemplate(
            'Inactive Template',
            'Inactive',
            false, // inactive
            true
        );
        insert inactiveTemplate;
    }
    
    @isTest
    static void testCreateProcessFromTemplate() {
        // Create a test Account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Get test data
        Process_Template__c mainTemplate = [SELECT Id FROM Process_Template__c WHERE Name = 'Main Process Template' LIMIT 1];
        
        Test.startTest();
        
        // Test getTemplates first
        List<Process_Template__c> templates = ProcessStepCtrl.getTemplates();
        System.assertEquals(1, templates.size(), 'Should return only active templates that can start processes');
        System.assertEquals('Main Process Template', templates[0].Name);
        
        // Test createProcessFromTemplate
        Id mainProcessId = ProcessStepCtrl.createProcessFromTemplate(
            mainTemplate.Id,
            testAccount.Id,
            'Account'
        );
        
        Test.stopTest();
        
        // Verify main process was created
        System.assertNotEquals(null, mainProcessId);
        Process__c mainProcess = [SELECT Id, Name, Status__c, StepNumber__c, TargetObjectId__c, TargetObjectType__c 
                                 FROM Process__c WHERE Id = :mainProcessId];
        System.assertEquals('Main Process Template', mainProcess.Name);
        System.assertEquals('New', mainProcess.Status__c);
        System.assertEquals(0, mainProcess.StepNumber__c);
        System.assertEquals(testAccount.Id, mainProcess.TargetObjectId__c);
        System.assertEquals('Account', mainProcess.TargetObjectType__c);
        
        // Verify sub-processes were created
        List<Process__c> subProcesses = [SELECT Id, Name, Status__c, StepNumber__c, ParentProcessId__c, 
                                        Due_Date__c, In_Progress_Requirement__c, Custom_Logic_In_Progress__c
                                        FROM Process__c WHERE ParentProcessId__c = :mainProcessId
                                        ORDER BY StepNumber__c];
        System.assertEquals(2, subProcesses.size());
        
        // Verify first sub-process
        Process__c subProcess1 = subProcesses[0];
        System.assertEquals('Sub Process 1', subProcess1.Name);
        System.assertEquals('New', subProcess1.Status__c);
        System.assertEquals(1, subProcess1.StepNumber__c);
        System.assertEquals('Previous Step Completed', subProcess1.In_Progress_Requirement__c);
        System.assertNotEquals(null, subProcess1.Due_Date__c);
        
        // Verify second sub-process
        Process__c subProcess2 = subProcesses[1];
        System.assertEquals('Sub Process 2', subProcess2.Name);
        System.assertEquals(2, subProcess2.StepNumber__c);
        System.assertEquals('Custom Logic', subProcess2.In_Progress_Requirement__c);
        System.assertEquals('1', subProcess2.Custom_Logic_In_Progress__c);
    }
    
    @isTest
    static void testProcessManagement() {
        // Create test Account
        Account testAccount = new Account(Name = 'Test Account 2');
        insert testAccount;
        
        // Create test process data
        Process_Template__c template = [SELECT Id FROM Process_Template__c WHERE Name = 'Main Process Template' LIMIT 1];
        
        // Create process from template
        Id mainProcessId = ProcessStepCtrl.createProcessFromTemplate(
            template.Id,
            testAccount.Id,
            'Account'
        );
        
        Test.startTest();
        
        // Test getProcessesForTarget
        List<Process__c> processes = ProcessStepCtrl.getProcessesForTarget(testAccount.Id);
        
        ProcessStepCtrl.updateProcessStatus(mainProcessId, 'In Progress');
        
        Process__c updatedProcess = [SELECT Status__c FROM Process__c WHERE Id = :mainProcessId];
        System.assertEquals('In Progress', updatedProcess.Status__c);
        
        // Test updateProcessStatus - error case (invalid process ID)
        try {
            ProcessStepCtrl.updateProcessStatus('a00000000000000000', 'Completed');
        } catch (AuraHandledException e) {
        }
        
        Test.stopTest();
    }
}