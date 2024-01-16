@isTest
public class CloudSignControllerTest {

    @isTest
    static void testSendPdf() {
        CloudSignController.SendPdfParameters pdfParameters = new CloudSignController.SendPdfParameters();
        pdfParameters.clientId = 'testid';
        pdfParameters.managerName = 'test manager';
        pdfParameters.managerEmail = 'test@example.com';
        pdfParameters.approverName = 'test approver';
        pdfParameters.approverEmail = 'testapprover@example.com';

        // テストデータの作成
        ContentVersion contentVersion = new ContentVersion(
            Title = 'TestContent'
            , PathOnClient = 'TestContent.pdf'
            , VersionData = Blob.valueOf('TestContentData')
            , OwnerId = UserInfo.getUserId()
        );
        insert contentVersion;

        List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];
        pdfParameters.pdfId = documents[0].Id;        
  
        List<CloudSignController.SendPdfParameters> paramList = new List<CloudSignController.SendPdfParameters>();
        paramList.add(pdfParameters);

        // テスト実行
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new CloudSignControllerTestMock());
        List<String> result = CloudSignController.sendPdf(paramList);
        Test.stopTest();

        // アサーション
        System.assertEquals(1, result.size());
        System.assertNotEquals('error', result[0]);
    }
}