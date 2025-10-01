@isTest
public class ProcessTriggerHandlerTest {
    
    @TestSetup
    static void makeData() {
        // Create process templates
        Process_Template__c template = TestDataFactory.createProcessTemplate(
            'Test Template',
            '3',
            true,
            false
        );
        insert template;
        
        // Create a parent process
        Process__c parentProcess = TestDataFactory.createProcess(
            'Parent Process',
            'New',
            0,
            template.Id
        );
        insert parentProcess;
        
        // Create child processes (steps)
        List<Process__c> childProcesses = new List<Process__c>();
        
        // Step 1 - Can always start (no validation)
        childProcesses.add(TestDataFactory.createProcessWithAllFields(
            'Step 1',
            'New',
            1,
            template.Id,
            null,
            null,
            DateTime.now().addDays(1),
            null, // No requirement
            parentProcess.Id,
            'Step 1 instructions',
            null,
            null
        ));
        
        // Step 2 - Requires previous step completed
        childProcesses.add(TestDataFactory.createProcessWithAllFields(
            'Step 2',
            'New',
            2,
            template.Id,
            null,
            null,
            DateTime.now().addDays(2),
            'Previous Step Completed',
            parentProcess.Id,
            'Step 2 instructions',
            null,
            null
        ));
        
        // Step 3 - Custom logic requiring step 1
        childProcesses.add(TestDataFactory.createProcessWithAllFields(
            'Step 3',
            'New',
            3,
            template.Id,
            null,
            '1', // Requires step 1 to be completed
            DateTime.now().addDays(3),
            'Custom Logic',
            parentProcess.Id,
            'Step 3 instructions',
            null,
            null
        ));
        
        insert childProcesses;
    }
    
    @isTest
    static void testCompletedDateIsSet() {
        Process__c step1 = [SELECT Id, Status__c, Completed_Date__c FROM Process__c WHERE Name = 'Step 1' LIMIT 1];
        
        Test.startTest();
        step1.Status__c = 'Completed';
        update step1;
        Test.stopTest();
        
        step1 = [SELECT Status__c, Completed_Date__c FROM Process__c WHERE Id = :step1.Id];
        System.assertEquals('Completed', step1.Status__c);
        System.assertNotEquals(null, step1.Completed_Date__c);
    }
    
    @isTest
    static void testPreviousStepValidation() {
        Process__c step1 = [SELECT Id FROM Process__c WHERE Name = 'Step 1' LIMIT 1];
        Process__c step2 = [SELECT Id FROM Process__c WHERE Name = 'Step 2' LIMIT 1];
        
        Test.startTest();
        
        // Should fail - step 1 not completed yet
        step2.Status__c = 'In Progress';
        try {
            update step2;
            System.assert(false, 'Should have failed');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Cannot move to In Progress until Step 1 is marked Completed'));
        }
        
        // Complete step 1, then step 2 should work
        step1.Status__c = 'Completed';
        update step1;
        
        step2.Status__c = 'In Progress';
        update step2; // Should succeed now
        
        Test.stopTest();
        
        step2 = [SELECT Status__c FROM Process__c WHERE Id = :step2.Id];
        System.assertEquals('In Progress', step2.Status__c);
    }
    
    @isTest
    static void testCustomLogicValidation() {
        Process__c step1 = [SELECT Id FROM Process__c WHERE Name = 'Step 1' LIMIT 1];
        Process__c step3 = [SELECT Id FROM Process__c WHERE Name = 'Step 3' LIMIT 1];
        
        Test.startTest();
        
        // Should fail - step 1 not completed yet
        step3.Status__c = 'In Progress';
        try {
            update step3;
            System.assert(false, 'Should have failed');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Custom logic condition not satisfied'));
        }
        
        // Complete step 1, then step 3 should work
        step1.Status__c = 'Completed';
        update step1;
        
        step3.Status__c = 'In Progress';
        update step3; // Should succeed now
        
        Test.stopTest();
        
        step3 = [SELECT Status__c FROM Process__c WHERE Id = :step3.Id];
        System.assertEquals('In Progress', step3.Status__c);
    }
}