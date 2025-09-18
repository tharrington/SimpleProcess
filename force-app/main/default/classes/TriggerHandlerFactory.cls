public class TriggerHandlerFactory {
    public static ITriggerHandler getHandler(String objectApiName) {
        String className = objectApiName.replace('__c', '') + 'TriggerHandler';

        // String className = 'myNamespace.' + objectApiName.replace('__c', '') + 'TriggerHandler';
        try {
            Type handlerType = Type.forName(className);
            if (handlerType == null) {
                throw new TriggerHandlerNotFoundException('No handler class found for: ' + className);
            }

            Object instance = handlerType.newInstance();
            if (!(instance instanceof ITriggerHandler)) {
                throw new TriggerHandlerNotFoundException(className + ' does not implement ITriggerHandler.');
            }

            return (ITriggerHandler) instance;
        } catch (Exception ex) {
            throw new TriggerHandlerNotFoundException('Error loading handler: ' + ex.getMessage());
        }
    }

    public class TriggerHandlerNotFoundException extends Exception {}
}