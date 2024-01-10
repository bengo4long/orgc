@isTest
private class B54_SyncRecordsTest {

    static testMethod void test() {
        Account acc = new Account(Name='TEST');
        insert acc ;
        
        Opportunity opp = new Opportunity(Name='test', StageName='A', CloseDate=Date.today(), Account=acc );
        insert opp;
        
        List<B54_SyncRecords.Request> requestList = new List<B54_SyncRecords.Request>();
        
        requestList.add( request(acc.Id) );
        requestList.add( request(new LIST<Id>{ acc.Id } ) );
        requestList.add( request(new LIST<Account>{ acc } ) ) ;
        
        B54_SyncRecords.SyncRecords( requestList );
        B54_SyncRecords sync = new B54_SyncRecords( requestList );
        sync.objectName = 'Opportunity' ;
        sync.requestOpportunityRecord(new Opportunity());
        sync.sync();
        sync.objectName = 'OpportunityLineItem' ;
        sync.requestOpportunityLineItemRecord(new OpportunityLineItem());
        sync.sync();
        sync.objectName = 'Revenue__c' ;
        sync.requestUriageRecord(new Revenue__c());
        sync.sync();
        sync.objectName = 'InvoiceInformation__c' ;
        sync.requestSeikyuRecord(new InvoiceInformation__c());
        sync.sync();
    }
    
   
    static B54_SyncRecords.Request request(Id recordId){
        B54_SyncRecords.Request request = new B54_SyncRecords.Request();
        request.recordId = recordId ;
        return request ;
    }
    static B54_SyncRecords.Request request(LIST<Id> recordIds){
        B54_SyncRecords.Request request = new B54_SyncRecords.Request();
        request.recordIds = recordIds ;
        return request ;
    }
    static B54_SyncRecords.Request request(LIST<Sobject> records){
        B54_SyncRecords.Request request = new B54_SyncRecords.Request();
        request.records = records ;
        return request ;
    }
}