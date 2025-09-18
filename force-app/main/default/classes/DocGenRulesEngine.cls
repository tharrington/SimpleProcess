public with sharing class DocGenRulesEngine {
    public static void runForCase(Id caseId) {
        Case onboardingCase = getCaseWithAllFields(caseId);
        System.debug('### got case: ' + onboardingCase);

        // Load all Gen Templates that use rule logic
        Map<Id, dfsle__GenTemplate__c> templatesById = new Map<Id, dfsle__GenTemplate__c>();
        for (dfsle__GenTemplate__c tmpl : [
            SELECT Id, Name, Conditions__c
            FROM dfsle__GenTemplate__c
            WHERE Conditions__c != null
        ]) {
            templatesById.put(tmpl.Id, tmpl);
        }

        // Load all rules across all templates
        Map<Id, List<Onboarding_Document_Rule__c>> rulesByTemplateId = new Map<Id, List<Onboarding_Document_Rule__c>>();
        for (Onboarding_Document_Rule__c rule : [
            SELECT Id, Rule_Number__c, Query__c, Condition__c, DocuSign_Gen_Template__c
            FROM Onboarding_Document_Rule__c
            WHERE Query__c != null AND Condition__c != null AND Rule_Number__c != null
        ]) {
            Id templateId = rule.DocuSign_Gen_Template__c;
            if (!rulesByTemplateId.containsKey(templateId)) {
                rulesByTemplateId.put(templateId, new List<Onboarding_Document_Rule__c>());
            }
            rulesByTemplateId.get(templateId).add(rule);
        }

        List<Onboarding_Document__c> docsToInsert = new List<Onboarding_Document__c>();
        for (Id templateId : templatesById.keySet()) {
            dfsle__GenTemplate__c tmpl = templatesById.get(templateId);
            List<Onboarding_Document_Rule__c> rules = rulesByTemplateId.get(templateId);
            if (rules == null) continue;

            // Map to store rule result
            Map<Decimal, Boolean> ruleResults = new Map<Decimal, Boolean>();
            for (Onboarding_Document_Rule__c rule : rules) {
                try {
                    String boundQuery = substituteVariables(rule.Query__c, onboardingCase);
                    List<SObject> results = Database.query(boundQuery);

                    if (results.isEmpty()) {
                        ruleResults.put(rule.Rule_Number__c, false);
                        continue;
                    }

                    SObject firstResult = results[0];
                    Boolean result = evaluateRuleCondition(rule.Condition__c, firstResult);
                    System.debug('### result for rule ' + rule.Rule_Number__c + ': ' + result);
                    ruleResults.put(rule.Rule_Number__c, result);
                } catch (Exception e) {
                    System.debug('### Error evaluating rule ' + rule.Rule_Number__c + ': ' + e.getMessage());
                    ruleResults.put(rule.Rule_Number__c, false); // fail-safe
                }
            }
            System.debug('### ruleResults ' + ruleResults);
            System.debug('### tmpl.Conditions__c ' + tmpl.Conditions__c);

            Boolean generateDoc = evaluateTemplateCondition(tmpl.Conditions__c, ruleResults);
            System.debug('### generateDoc ' + generateDoc);
            if (generateDoc) {
                Onboarding_Document__c doc = new Onboarding_Document__c(
                    Case__c = onboardingCase.Id,
                    Name = 'Onboarding Document for ' + onboardingCase.Account.Name + ' - ' + tmpl.Name,
                    Docusign_Gen_Template__c = tmpl.Id
                );
                docsToInsert.add(doc);
            }
        }

        if (!docsToInsert.isEmpty()) {
            // After insert docsToInsert...
            insert docsToInsert;
            System.debug('### Inserted ' + docsToInsert);

            Set<Id> templateIds = new Set<Id>();
            for (Onboarding_Document__c doc : docsToInsert) {
                templateIds.add(doc.Docusign_Gen_Template__c);
            }

            // Get all related onboarding questions
            Map<Id, List<Id>> questionsByTemplateId = new Map<Id, List<Id>>();
            Set<Id> allQuestionIds = new Set<Id>();

            for (Onboarding_Question_Document__c link : [
                SELECT DocuSign_Gen_Template__c, Onboarding_Question__c
                FROM Onboarding_Question_Document__c
                WHERE DocuSign_Gen_Template__c IN :templateIds
            ]) {
                if (!questionsByTemplateId.containsKey(link.DocuSign_Gen_Template__c)) {
                    questionsByTemplateId.put(link.DocuSign_Gen_Template__c, new List<Id>());
                }
                questionsByTemplateId.get(link.DocuSign_Gen_Template__c).add(link.Onboarding_Question__c);
                allQuestionIds.add(link.Onboarding_Question__c);
            }

            

            // Upsert Onboarding_Answer__c per (Account + Question)
            Map<String, Onboarding_Answer__c> onboardingAnswerByKey = new Map<String, Onboarding_Answer__c>();
            for (Onboarding_Answer__c answer : [
                SELECT Id, Onboarding_Question__c, Account__c, Onboarding_Question__r.Question__c
                FROM Onboarding_Answer__c
                WHERE Account__c = :onboardingCase.AccountId
                AND Onboarding_Question__c IN :allQuestionIds
            ]) {
                String key = answer.Account__c + '_' + answer.Onboarding_Question__c;
                onboardingAnswerByKey.put(key, answer);
            }

            List<Onboarding_Answer__c> answersToInsert = new List<Onboarding_Answer__c>();
            for (Id questionId : allQuestionIds) {
                String key = onboardingCase.AccountId + '_' + questionId;
                if (!onboardingAnswerByKey.containsKey(key)) {
                    Onboarding_Answer__c newAnswer = new Onboarding_Answer__c(
                        Account__c = onboardingCase.AccountId,
                        Onboarding_Question__c = questionId
                    );
                    answersToInsert.add(newAnswer);
                    onboardingAnswerByKey.put(key, newAnswer);
                }
            }

            if (!answersToInsert.isEmpty()) {
                insert answersToInsert;
            }

            // Create Document Questions per document
            List<Document_Question__c> docQuestionsToInsert = new List<Document_Question__c>();
            Map<Id, List<Document_Question__c>> docQuestionsByDocId = new Map<Id, List<Document_Question__c>>();

            for (Onboarding_Document__c doc : docsToInsert) {
                List<Id> questionIds = questionsByTemplateId.get(doc.Docusign_Gen_Template__c);
                if (questionIds == null) continue;

                for (Id qId : questionIds) {
                    Document_Question__c dq = new Document_Question__c(
                        Onboarding_Document__c = doc.Id,
                        Onboarding_Question__c = qId
                    );
                    docQuestionsToInsert.add(dq);

                    if (!docQuestionsByDocId.containsKey(doc.Id)) {
                        docQuestionsByDocId.put(doc.Id, new List<Document_Question__c>());
                    }
                    docQuestionsByDocId.get(doc.Id).add(dq);
                }
            }

            insert docQuestionsToInsert;

            // Create Document Answers (junction between Document Question and Onboarding Answer)
            List<Document_Answer__c> docAnswers = new List<Document_Answer__c>();

            for (Document_Question__c dq : docQuestionsToInsert) {
                String key = onboardingCase.AccountId + '_' + dq.Onboarding_Question__c;
                Onboarding_Answer__c matchingAnswer = onboardingAnswerByKey.get(key);

                if (matchingAnswer != null) {
                    docAnswers.add(new Document_Answer__c(
                        Document_Question__c = dq.Id,
                        Onboarding_Answer__c = matchingAnswer.Id
                    ));
                }
            }

            insert docAnswers;
        }
    }


    // Replace :record.Field with actual values 
    private static String substituteVariables(String query, SObject contextRecord) {
        Pattern tokenPattern = Pattern.compile(':(record(?:\\.[a-zA-Z0-9_]+)+)');
        Matcher matcher = tokenPattern.matcher(query);
        Set<String> allTokens = new Set<String>();

        while (matcher.find()) {
            allTokens.add(matcher.group(1)); // group 1 = e.g. record.Account.Industry
        }

        for (String token : allTokens) {
            String[] parts = token.split('\\.');
            SObject current = contextRecord;
            Object value = null;

            try {
                for (Integer i = 1; i < parts.size(); i++) {
                    String field = parts[i];
                    value = current.get(field);
                    if (value instanceof SObject) {
                        current = (SObject)value;
                    } else {
                        break;
                    }
                }
            } catch (Exception e) {
                value = null; // Fails silently and leaves token untouched if invalid
            }

            String replacement = (value != null)
                ? '\'' + String.valueOf(value).replace('\'', '\\\'') + '\''
                : 'NULL';
            query = query.replace(':' + token, replacement);
        }

        return query;
    }


    // Very simple condition evaluator: supports == only
    private static Boolean evaluateRuleCondition(String condition, SObject result) {
        if (String.isBlank(condition)) return false;

        // Example: QueryResult.Type == 'Test'
        Pattern pattern = Pattern.compile('QueryResult\\.([a-zA-Z0-9_]+)\\s*==\\s*\'([^\']+)\'');
        Matcher matcher = pattern.matcher(condition);

        if (matcher.find()) {
            String field = matcher.group(1);
            String expected = matcher.group(2);
            Object actual = result.get(field);
            return actual != null && String.valueOf(actual) == expected;
        }

        return false;
    }

    private static Boolean evaluateTemplateCondition(String expression, Map<Decimal, Boolean> ruleResults) {
        if (String.isBlank(expression)) return false;

        // Replace rule numbers with true/false
        String expr = expression;
        for (Decimal ruleNum : ruleResults.keySet()) {
            expr = expr.replaceAll('\\b' + String.valueOf(ruleNum) + '\\b', String.valueOf(ruleResults.get(ruleNum)));
        }

        System.debug('### Evaluating expression: ' + expr);

        return BooleanExpressionEvaluator.evaluate(expr);
    }



    private static Case getCaseWithAllFields(Id caseId) {
        // Get all field names
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Case.fields.getMap();
        List<String> fieldNames = new List<String>(fieldMap.keySet());

        // Construct SOQL query string
        String soql = 'SELECT Account.Name, ' + String.join(fieldNames, ',') + ' FROM Case WHERE Id = :caseId';

        // Run dynamic SOQL
        List<SObject> results = Database.query(soql);
        return (results.isEmpty() ? null : (Case)results[0]);
    }

}

/*
List<Document_Answer__c> docAnswers = [select id from Document_Answer__c];
delete docAnswers;

List<Document_Question__c> docQuestions = [select id from Document_Question__c];
delete docQuestions;

List<Onboarding_Answer__c> obAnswers = [select id from Onboarding_Answer__c];
delete obAnswers;

List<Onboarding_Document__c> obDocs = [select id from Onboarding_Document__c];
delete obDocs;
*/