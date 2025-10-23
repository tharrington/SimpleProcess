@isTest
private class CompletedProcessesCtrlTest {

    @testSetup
    static void setup() {
        // Create test account as target object
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        // Create process template
        Process_Template__c template = TestDataFactory.createProcessTemplate(
            'Test Template',
            '5',
            true,
            false
        );
        insert template;

        // Create completed parent process
        Process__c completedParent = TestDataFactory.createProcessWithAllFields(
            'Completed Parent Process',
            'Completed',
            5,
            template.Id,
            Date.today(),
            null,
            null,
            null,
            null,
            '5',
            testAccount.Id,
            'Account'
        );
        insert completedParent;

        // Create child processes for completed parent
        List<Process__c> childProcesses = new List<Process__c>();
        for (Integer i = 1; i <= 3; i++) {
            Process__c child = TestDataFactory.createProcessWithAllFields(
                'Child Process ' + i,
                'Completed',
                i,
                template.Id,
                Date.today(),
                null,
                Date.today().addDays(7),
                null,
                completedParent.Id,
                '5',
                testAccount.Id,
                'Account'
            );
            childProcesses.add(child);
        }
        insert childProcesses;

        // Create in-progress parent process (should not be returned)
        Process__c inProgressParent = TestDataFactory.createProcessWithAllFields(
            'In Progress Parent Process',
            'In Progress',
            3,
            template.Id,
            null,
            null,
            null,
            null,
            null,
            '5',
            testAccount.Id,
            'Account'
        );
        insert inProgressParent;

        // Create completed process with different target object (should not be returned)
        Account differentAccount = new Account(Name = 'Different Account');
        insert differentAccount;

        Process__c differentTargetProcess = TestDataFactory.createProcessWithAllFields(
            'Different Target Process',
            'Completed',
            5,
            template.Id,
            Date.today(),
            null,
            null,
            null,
            null,
            '5',
            differentAccount.Id,
            'Account'
        );
        insert differentTargetProcess;
    }

    @isTest
    static void testGetCompletedProcesses_ReturnsOnlyCompletedProcessesForTargetObject() {
        // Given
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        // When
        Test.startTest();
        List<Process__c> results = CompletedProcessesCtrl.getCompletedProcesses(testAccount.Id);
        Test.stopTest();

        // Then
        System.assertEquals(1, results.size(), 'Should return only 1 completed parent process');
        System.assertEquals('Completed', results[0].Status__c, 'Process status should be Completed');
        System.assertEquals(testAccount.Id, results[0].TargetObjectId__c, 'Process should belong to test account');
        System.assertNotEquals(null, results[0].Completed_Date__c, 'Completed date should be populated');
    }

    @isTest
    static void testGetCompletedProcesses_ReturnsChildProcesses() {
        // Given
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        // When
        Test.startTest();
        List<Process__c> results = CompletedProcessesCtrl.getCompletedProcesses(testAccount.Id);
        Test.stopTest();

        // Then
        System.assertEquals(1, results.size(), 'Should return 1 parent process');
        System.assertEquals(3, results[0].ChildProcesses__r.size(), 'Parent should have 3 child processes');

        // Verify child processes are ordered by step number
        Integer previousStepNumber = 0;
        for (Process__c child : results[0].ChildProcesses__r) {
            System.assert(child.StepNumber__c > previousStepNumber, 'Child processes should be ordered by step number');
            previousStepNumber = Integer.valueOf(child.StepNumber__c);
        }
    }

    @isTest
    static void testGetCompletedProcesses_ExcludesInProgressProcesses() {
        // Given
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        // When
        Test.startTest();
        List<Process__c> results = CompletedProcessesCtrl.getCompletedProcesses(testAccount.Id);
        Test.stopTest();

        // Then
        for (Process__c process : results) {
            System.assertNotEquals('In Progress', process.Status__c, 'Should not return in-progress processes');
            System.assertNotEquals('New', process.Status__c, 'Should not return new processes');
        }
    }

    @isTest
    static void testGetCompletedProcesses_OrdersByCreatedDateDesc() {
        // Given
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Process_Template__c template = [SELECT Id FROM Process_Template__c LIMIT 1];

        // When
        Test.startTest();
        List<Process__c> results = CompletedProcessesCtrl.getCompletedProcesses(testAccount.Id);
        Test.stopTest();

        // Then - only one completed process should exist from setup
        System.assertEquals(1, results.size(), 'Should return 1 completed process');
        System.assertNotEquals(null, results[0].CreatedDate, 'CreatedDate should be populated');
    }

    @isTest
    static void testGetCompletedProcesses_NoCompletedProcesses() {
        // Given
        Account newAccount = new Account(Name = 'New Account');
        insert newAccount;

        // When
        Test.startTest();
        List<Process__c> results = CompletedProcessesCtrl.getCompletedProcesses(newAccount.Id);
        Test.stopTest();

        // Then
        System.assertEquals(0, results.size(), 'Should return empty list when no completed processes exist');
    }

    @isTest
    static void testGetCompletedProcesses_IncludesAllRequiredFields() {
        // Given
        Account testAccount = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        // When
        Test.startTest();
        List<Process__c> results = CompletedProcessesCtrl.getCompletedProcesses(testAccount.Id);
        Test.stopTest();

        // Then
        System.assertEquals(1, results.size(), 'Should return 1 process');
    }
}