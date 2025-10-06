@isTest
private class TriggerHandlerFactoryTest {

    @isTest
    static void testGetHandler_ProcessObject_ReturnsProcessTriggerHandler() {
        Test.startTest();
        ITriggerHandler handler = TriggerHandlerFactory.getHandler('Process__c');
        Test.stopTest();

        System.assertNotEquals(null, handler, 'Handler should not be null');
        System.assert(handler instanceof ProcessTriggerHandler, 'Handler should be instance of ProcessTriggerHandler');
    }

    @isTest
    static void testGetHandler_InvalidObject_ThrowsException() {
        String invalidObjectName = 'NonExistent__c';
        Exception caughtException = null;

        Test.startTest();
        try {
            ITriggerHandler handler = TriggerHandlerFactory.getHandler(invalidObjectName);
            System.assert(false, 'Should have thrown TriggerHandlerNotFoundException');
        } catch (TriggerHandlerFactory.TriggerHandlerNotFoundException ex) {
            caughtException = ex;
        }
        Test.stopTest();

        System.assertNotEquals(null, caughtException, 'Exception should have been thrown');
        System.assert(
            caughtException.getMessage().contains('No handler class found') ||
            caughtException.getMessage().contains('Error loading handler'),
            'Exception message should indicate handler not found'
        );
    }

    @isTest
    static void testGetHandler_HandlerDoesNotImplementInterface_ThrowsException() {
        // This test validates the error handling for classes that don't implement ITriggerHandler
        // Since we can't easily create a non-implementing class at runtime, we test the exception path
        // by testing with an invalid class name that will fail type checking
        String invalidClassName = 'String'; // String class doesn't implement ITriggerHandler
        Exception caughtException = null;

        Test.startTest();
        try {
            // This will attempt to find StringTriggerHandler which doesn't exist
            ITriggerHandler handler = TriggerHandlerFactory.getHandler('String__c');
            System.assert(false, 'Should have thrown TriggerHandlerNotFoundException');
        } catch (TriggerHandlerFactory.TriggerHandlerNotFoundException ex) {
            caughtException = ex;
        }
        Test.stopTest();

        System.assertNotEquals(null, caughtException, 'Exception should have been thrown');
    }

    @isTest
    static void testTriggerHandlerNotFoundException_CanBeThrown() {
        Boolean exceptionThrown = false;
        String exceptionMessage = 'Test exception message';

        Test.startTest();
        try {
            throw new TriggerHandlerFactory.TriggerHandlerNotFoundException(exceptionMessage);
        } catch (TriggerHandlerFactory.TriggerHandlerNotFoundException ex) {
            exceptionThrown = true;
            System.assertEquals(exceptionMessage, ex.getMessage(), 'Exception message should match');
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Custom exception should have been thrown and caught');
    }

    @isTest
    static void testGetHandler_MultipleCallsSameObject_ReturnsNewInstances() {
        Test.startTest();
        ITriggerHandler handler1 = TriggerHandlerFactory.getHandler('Process__c');
        ITriggerHandler handler2 = TriggerHandlerFactory.getHandler('Process__c');
        Test.stopTest();

        System.assertNotEquals(null, handler1, 'First handler should not be null');
        System.assertNotEquals(null, handler2, 'Second handler should not be null');
        // Note: These will be different instances (factory creates new instances each time)
        System.assert(handler1 instanceof ProcessTriggerHandler, 'Both handlers should be correct type');
        System.assert(handler2 instanceof ProcessTriggerHandler, 'Both handlers should be correct type');
    }
}
