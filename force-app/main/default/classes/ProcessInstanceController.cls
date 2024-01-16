global with sharing class ProcessInstanceController {

    @InvocableMethod(label='承認申請承認済み')
    public static List<Boolean> isApproval(List<IsApprovalParameters> params) {
        IsApprovalParameters param = params[0];
        String oppId = param.oppId;
        Id userId = param.userId;

        List<ProcessInstance> pi = [SELECT Id, status, TargetObjectId FROM ProcessInstance WHERE SubmittedById = :userId AND TargetObjectId = :oppId AND Status = 'Approved' ORDER BY CreatedDate Desc];
        if (pi.size() > 0) {
            return new List<Boolean>{true};
        }

        return new List<Boolean>{false};
    }

    global class IsApprovalParameters {
        @invocableVariable
        public ID oppId;
        @invocableVariable
        public ID userId;
    }
}