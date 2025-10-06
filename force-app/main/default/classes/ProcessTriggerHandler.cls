public with sharing class ProcessTriggerHandler implements ITriggerHandler {

    /*
    list<process__c> procs = [select id from process__c];
    delete procs;
    */
    private static final String STATUS_NEW = 'New';
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
    private void handleAfterDelete(List<Process__c> oldRecords) {}

    private void handleBeforeUpdate(Map<Id, Process__c> oldMap, Map<Id, Process__c> newMap) {
        List<Process__c> changed = new List<Process__c>();
        Set<Id> parentProcessIdsBeingCompleted = new Set<Id>();
        
        for (Id id : newMap.keySet()) {
            Process__c oldP = oldMap.get(id);
            Process__c newP = newMap.get(id);
            if (oldP.Status__c != newP.Status__c &&
                (newP.Status__c == STATUS_IN_PROGRESS || newP.Status__c == STATUS_COMPLETED)) {

                if (newP.Status__c == STATUS_COMPLETED) {
                    newP.Completed_Date__c = System.now();
                    // Track any process being marked as completed (not just Step 0)
                    parentProcessIdsBeingCompleted.add(newP.Id);
                }

                changed.add(newP);
            }
        }

        if (changed.isEmpty()) return;

        // Validate parent processes - they can only be completed if all children are completed
        if (!parentProcessIdsBeingCompleted.isEmpty()) {
            Map<Id, Process__c> parentProcesses = new Map<Id, Process__c>([
                SELECT Id, 
                    (SELECT Id, Status__c FROM ChildProcesses__r)
                FROM Process__c
                WHERE Id IN :parentProcessIdsBeingCompleted
            ]);

            for (Process__c proc : changed) {
                if (!parentProcessIdsBeingCompleted.contains(proc.Id)) continue;
                
                Process__c parentProcess = parentProcesses.get(proc.Id);
                // Only validate if this process actually has children
                if (parentProcess != null && !parentProcess.ChildProcesses__r.isEmpty()) {
                    for (Process__c child : parentProcess.ChildProcesses__r) {
                        if (child.Status__c != STATUS_COMPLETED) {
                            proc.addError('Cannot mark parent process as Completed until all child steps are completed.');
                            break;
                        }
                    }
                }
            }
        }

        // Validate child processes (Step 1+)
        Set<Id> parentProcessIds = new Set<Id>();
        for (Process__c proc : changed) {
            if (proc.ParentProcessId__c != null) {
                parentProcessIds.add(proc.ParentProcessId__c);
            }
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
                Integer prevStep = Integer.valueOf(proc.StepNumber__c - 1);
                
                // If previous step is 0, skip validation (Step 0 doesn't need to be completed)
                if (prevStep == 0) {
                    continue;
                }
                
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

    private void handleAfterUpdate(Map<Id, Process__c> oldMap, Map<Id, Process__c> newMap) {
        Set<Id> parentProcessIds = new Set<Id>();
        
        // Collect parent process IDs where child status changed
        for (Id id : newMap.keySet()) {
            Process__c oldP = oldMap.get(id);
            Process__c newP = newMap.get(id);
            
            if (oldP.Status__c != newP.Status__c && newP.ParentProcessId__c != null) {
                parentProcessIds.add(newP.ParentProcessId__c);
            }
        }

        if (parentProcessIds.isEmpty()) return;

        // Recursively update parent statuses
        updateParentStatuses(parentProcessIds);
    }

    private void updateParentStatuses(Set<Id> parentProcessIds) {
        if (parentProcessIds.isEmpty()) return;

        // Query parent processes and their children
        Map<Id, Process__c> parentProcesses = new Map<Id, Process__c>([
            SELECT Id, Status__c, StepNumber__c, ParentProcessId__c,
                (SELECT Id, Status__c FROM ChildProcesses__r)
            FROM Process__c
            WHERE Id IN :parentProcessIds
        ]);

        List<Process__c> parentsToUpdate = new List<Process__c>();
        Set<Id> grandparentIds = new Set<Id>();

        for (Process__c parent : parentProcesses.values()) {
            List<Process__c> children = parent.ChildProcesses__r;
            
            // Skip if no children
            if (children.isEmpty()) continue;

            Boolean allCompleted = true;
            Boolean anyInProgress = false;

            for (Process__c child : children) {
                if (child.Status__c != STATUS_COMPLETED) {
                    allCompleted = false;
                }
                if (child.Status__c == STATUS_IN_PROGRESS) {
                    anyInProgress = true;
                }
            }

            String newStatus = null;

            // If all children are completed, mark parent as completed
            if (allCompleted && parent.Status__c != STATUS_COMPLETED) {
                newStatus = STATUS_COMPLETED;
            }
            // If any child is in progress, mark parent as in progress
            else if (anyInProgress && parent.Status__c == STATUS_NEW) {
                newStatus = STATUS_IN_PROGRESS;
            }

            if (newStatus != null) {
                parent.Status__c = newStatus;
                if (newStatus == STATUS_COMPLETED) {
                    parent.Completed_Date__c = System.now();
                }
                parentsToUpdate.add(parent);
                
                // Track grandparents to update recursively
                if (parent.ParentProcessId__c != null) {
                    grandparentIds.add(parent.ParentProcessId__c);
                }
            }
        }

        if (!parentsToUpdate.isEmpty()) {
            update parentsToUpdate;
            
            // Recursively update grandparents
            if (!grandparentIds.isEmpty()) {
                updateParentStatuses(grandparentIds);
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