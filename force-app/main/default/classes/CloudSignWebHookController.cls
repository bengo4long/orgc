@RestResource(urlMapping='/agreements')
global class CloudSignWebHookController {    
    @HttpPost
    global static String doPost() {
        RestRequest req = RestContext.request;
        String reqString = req.requestBody.toString();
        Map<String, Object> reqJson = (Map<String, Object>)JSON.deserializeUntyped(reqString);
        String documentId = (String)reqJson.get('documentID');

        CloudSignWebHookHistory__c webHookHistory = new CloudSignWebHookHistory__c();
        webHookHistory.Text__c = (String)reqJson.get('text');
        webHookHistory.Status__c = (Integer)reqJson.get('status');
        webHookHistory.Json__c = reqString;

        List<Opportunity> oppList = [SELECT Id, CloudSignDocumentId__c, CloudSignStatus__c FROM Opportunity WHERE CloudSignDocumentId__c = :documentId];
        if (oppList.size() > 0) {
            Opportunity opp = oppList[0];
            switch on (Integer)reqJson.get('status') {
                when 1 {
                    opp.CloudSignStatus__c = '先方確認中';
                    opp.StageName = '契約書締結待ち';
                }
                when 2 {
                    opp.CloudSignStatus__c = '締結完了';
                    opp.StageName = '受注';

                    String text = (String)reqJson.get('text');
                    System.debug(text);
                    Integer startIndex = text.indexOf('<');
                    Integer endIndex = text.indexOf('>');
                    if (startIndex != -1 && endIndex != -1) {
                        // URLを取得する
                        String url = text.substring(startIndex + 1, endIndex);
                        System.debug(url); // URLを表示する（デバッグログに出力）
            
                        opp.DocumentConfirmationUrl__c = url;
                    }
                }
                when 3 {
                    opp.CloudSignStatus__c = '取り消し・却下';
                }
                when else {
                    opp.CloudSignStatus__c = '';
                }
            }
            update opp;
        }

        return 'Success';
    }
}