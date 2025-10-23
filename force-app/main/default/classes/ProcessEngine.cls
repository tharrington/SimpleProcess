public without sharing class ProcessEngine {
    public static void run(Process__c process) {
        process = [
            SELECT Id, ProcessTemplateId__c, TargetObjectId__c, TargetObjectType__c
            FROM Process__c
            WHERE Id = :process.Id
        ];

        List<Process_Rule__c> rules = [
            SELECT Id, FieldName__c, Operator__c, Value__c, Active__c, Order__c
            FROM Process_Rule__c
            WHERE Active__c = TRUE AND ProcessTemplate__c = :process.ProcessTemplateId__c
            ORDER BY Order__c ASC
        ];

        String targetId = process.TargetObjectId__c;
        SObject targetRecord = Database.query(
            'SELECT Id, ' + getFields(rules) +
            ' FROM ' + process.TargetObjectType__c +
            ' WHERE Id = :targetId'
        );

        for (Process_Rule__c rule : rules) {
            Boolean passed = evaluateRule(rule, targetRecord);
        }

        // Evaluate subprocesses recursively
        List<Process__c> childProcesses = [
            SELECT Id, ProcessTemplateId__c, TargetObjectId__c, TargetObjectType__c
            FROM Process__c
            WHERE ParentProcessId__c = :process.Id
        ];

        for (Process__c child : childProcesses) {
            run(child);
        }
    }


    private static Boolean evaluateRule(Process_Rule__c rule, SObject record) {
        Object fieldValue = record.get(rule.FieldName__c);
        if (fieldValue == null) return false;

        String actual = String.valueOf(fieldValue).trim();
        String expected = rule.Value__c != null ? rule.Value__c.trim() : '';

        switch on rule.Operator__c {
            when 'Equals'        { return actual == expected; }
            when 'Not Equals'    { return actual != expected; }
            when 'Contains'      { return actual.contains(expected); }
            when 'Starts With'   { return actual.startsWith(expected); }
            when 'Ends With'     { return actual.endsWith(expected); }
            when else            { return false; }
        }
    }

    private static String getFields(List<Process_Rule__c> rules) {
        Set<String> fields = new Set<String>();
        for (Process_Rule__c rule : rules) {
            if (String.isNotBlank(rule.FieldName__c)) {
                fields.add(rule.FieldName__c);
            }
        }
        return String.join(new List<String>(fields), ',');
    }
}