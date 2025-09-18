public with sharing class DocGenRulesEngineAction {
    @InvocableMethod(label='Generate Onboarding Docs')
    public static void generate(List<Id> caseIds) {
        for (Id caseId : caseIds) {
            DocGenRulesEngine.runForCase(caseId);
        }
    }
}


/**
 Map<String, Object> mergeFields = new Map<String, Object>{
    'test_field' => 'Hello test'
};

dfsle.GeneratorSettings settings = new dfsle.GeneratorSettings();
settings.templateId = 'a0OgK000003eMGDUA2';
settings.mergeFieldMap = mergeFields;
settings.outputFormat = dfsle.OutputFormat.PDF;
settings.name = 'TestFileOutput.pdf';
settings.parentId = '500gK00000BNwWQQA1'; 

// Generate the document
dfsle.GeneratedDocument result = dfsle.DocumentGenerator.generate(settings);
 */