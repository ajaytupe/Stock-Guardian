public with sharing class RunFlowInSystemContext {
    public static void executeFlow() {
        Flow.Interview flowInterview = Flow.Interview.createInterview(
            'Auto_Approval_Submission',
            new Map<String, Object>()
        );
        flowInterview.start(); // This runs the flow in system context
    }
}
