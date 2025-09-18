public with sharing class ProcessTriggerHandler implements ITriggerHandler {

    private static final String STATUS_IN_PROGRESS = 'In Progress';
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String REQUIREMENT_PREVIOUS_STEP = 'Previous Step Completed';
    private static final String REQUIREMENT_CUSTOM_LOGIC = 'Custom Logic';

    public void handle(TriggerContext context) {
        if (context.isBefore) {
            if (context.isInsert) {
                handleBeforeInsert((List<Process__c>) context.newRecords);
            } else if (context.isUpdate) {
                handleBeforeUpdate(
                    (Map<Id, Process__c>) context.oldMap,
                    (Map<Id, Process__c>) context.newMap
                );
            } else if (context.isDelete) {
                handleBeforeDelete((List<Process__c>) context.oldRecords);
            }
        } else if (context.isAfter) {
            if (context.isInsert) {
                handleAfterInsert((List<Process__c>) context.newRecords);
            } else if (context.isUpdate) {
                handleAfterUpdate(
                    (Map<Id, Process__c>) context.oldMap,
                    (Map<Id, Process__c>) context.newMap
                );
            } else if (context.isDelete) {
                handleAfterDelete((List<Process__c>) context.oldRecords);
            }
        }
    }

    private void handleBeforeInsert(List<Process__c> newRecords) {}
    private void handleBeforeDelete(List<Process__c> oldRecords) {}
    private void handleAfterInsert(List<Process__c> newRecords) {}
    private void handleAfterUpdate(Map<Id, Process__c> oldMap, Map<Id, Process__c> newMap) {}
    private void handleAfterDelete(List<Process__c> oldRecords) {}

    private void handleBeforeUpdate(Map<Id, Process__c> oldMap, Map<Id, Process__c> newMap) {
        List<Process__c> changed = new List<Process__c>();
        for (Id id : newMap.keySet()) {
            Process__c oldP = oldMap.get(id);
            Process__c newP = newMap.get(id);
            if (oldP.Status__c != newP.Status__c &&
                (newP.Status__c == STATUS_IN_PROGRESS || newP.Status__c == STATUS_COMPLETED)) {

                if (newP.Status__c == STATUS_COMPLETED) {
                    newP.Completed_Date__c = System.now();
                }

                changed.add(newP);
            }

        }

        if (changed.isEmpty()) return;

        Set<Id> parentProcessIds = new Set<Id>();
        for (Process__c proc : changed) {
            parentProcessIds.add(proc.ParentProcessId__c);
        }

        // Get all sibling steps
        List<Process__c> allSteps = [
            SELECT Id, ParentProcessId__c, StepNumber__c, Status__c
            FROM Process__c
            WHERE ParentProcessId__c IN :parentProcessIds
        ];

        Map<Id, List<Process__c>> stepsByParent = new Map<Id, List<Process__c>>();
        for (Process__c step : allSteps) {
            if (!stepsByParent.containsKey(step.ParentProcessId__c)) {
                stepsByParent.put(step.ParentProcessId__c, new List<Process__c>());
            }
            stepsByParent.get(step.ParentProcessId__c).add(step);
        }

        for (Process__c proc : changed) {
            List<Process__c> siblings = stepsByParent.get(proc.ParentProcessId__c);
            if (siblings == null) continue;

            if (proc.In_Progress_Requirement__c == REQUIREMENT_PREVIOUS_STEP) {
                Integer prevStep = Integer.ValueOf(proc.StepNumber__c - 1);
                Boolean foundAndCompleted = false;
                for (Process__c s : siblings) {
                    if (s.StepNumber__c == prevStep && s.Status__c == STATUS_COMPLETED) {
                        foundAndCompleted = true;
                        break;
                    }
                }
                if (!foundAndCompleted) {
                    proc.addError('Cannot move to ' + proc.Status__c + ' until Step ' + prevStep + ' is marked Completed.');
                }
            }

            if (proc.In_Progress_Requirement__c == REQUIREMENT_CUSTOM_LOGIC) {
                // Build step map
                Map<String, Boolean> stepStatusMap = new Map<String, Boolean>();
                for (Process__c s : siblings) {
                    stepStatusMap.put(String.valueOf(s.StepNumber__c), s.Status__c == STATUS_COMPLETED);
                }

                // Evaluate the logic string (e.g. "1 AND 2 OR 3")
                String logic = proc.Custom_Logic_In_Progress__c;
                if (!evaluateStepLogic(logic, stepStatusMap)) {
                    proc.addError('Custom logic condition not satisfied: ' + logic);
                }
            }
        }
    }

    private Boolean evaluateStepLogic(String logic, Map<String, Boolean> stepStatusMap) {
        if (String.isBlank(logic)) return false;

        List<String> tokens = logic.split('\\s+');
        Boolean result = null;
        String op = null;

        for (String token : tokens) {
            if (token == 'AND' || token == 'OR') {
                op = token;
            } else {
                Boolean current = stepStatusMap.get(token) == true;

                if (result == null) {
                    result = current;
                } else if (op == 'AND') {
                    result = result && current;
                } else if (op == 'OR') {
                    result = result || current;
                }
            }
        }

        return result != null && result;
    }
}