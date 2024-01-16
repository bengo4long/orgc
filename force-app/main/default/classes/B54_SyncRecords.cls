public class B54_SyncRecords {
    @InvocableMethod(label='SyncRecords' description='SyncRecords')
    public static LIST<Response> SyncRecords (List<Request> requestList) {
        B54_SyncRecords sync = new B54_SyncRecords( requestList );
        return sync.responses ;
        
    }
    public LIST<Response> responses = new LIST<Response>();
    public LIST<MAP<String,Object>> requestRecords = new LIST<MAP<String,Object>>();
    public String externalField_OrgC ;
    public String externalField_OrgA ;
    public String objectName ;
	public String objectName_OrgA ;
    public LIST<Id> recordIds = new LIST<Id>() ;
    public B54_SyncRecords( List<Request> requestList ){
        for (Request request : requestList ){
            if( request.records != null ) init(request.records) ;
            else if( request.recordIds != null ) init(request.recordIds) ;
            else if( request.recordId != null ) init(request.recordId) ;
        }
    }
    public class Request {
        @InvocableVariable(label='recordIds' description='recordIds')
        public LIST<Id> recordIds;
        @InvocableVariable(label='recordId' description='recordId')
        public Id recordId;
        @InvocableVariable(label='records' description='records')
        public LIST<SObject> records;
    }
    public class Response {
        @InvocableVariable(label='success' description='success')
        public Boolean success;
        @InvocableVariable(label='error' description='error')
        public String error;
    }
    public class Result {
        public Boolean success;
        public String id;
    }
    public void init(Id recordId){
        recordIds.add( recordId );
        init();
    } 
    public void init(LIST<Sobject> records){
        recordIds = new LIST<Id>( (new MAP<Id,Sobject>( records )).keyset() );
        init();
    } 
    public void init(LIST<Id> recordIds){
        this.recordIds = recordIds ;
        init();
    }
    public void init(){
        setObjectName();
        sync();
    }
    public void setObjectName(){
        objectName = recordIds.get(0)?.getSObjectType().getDescribe().getName();
        objectName_OrgA = objectName ;
    }
    public void sync(){
        switch on objectName {
            when 'Account' {
                externalField_OrgC = 'OrgC_AccountId__c' ;
                externalField_OrgA = 'OrgA_AccountId__c' ;
                for( Account record : [
                    SELECT 
                    Id, 
                    Name 
                    FROM Account WHERE Id In: recordIds AND OrgA_AccountId__c = null ] ) requestRecords.add(requestAccountRecord(record));
            }
            when 'Opportunity' {
                externalField_OrgC = 'OrgC_OpportunityId__c' ;
                externalField_OrgA = 'OrgA_OpportunityId__c' ;
                for( Opportunity record : [
                    SELECT 
                    Id, 
                    Name,
                    CloseDate, 
                    StageName, 
                    BillingCollectionSite__c, 
                    CollectionMethod__c,
                    Account.OrgA_AccountId__c
                    FROM Opportunity WHERE Id In: recordIds ] ) requestRecords.add(requestOpportunityRecord(record));
            }
            when 'OpportunityLineItem' {
                externalField_OrgC = 'OrgC_OpportunityLineitemId__c' ;
                externalField_OrgA = 'OrgA_OpportunityLineitemId__c' ;
                for( OpportunityLineitem record : [
                    SELECT
                    Id,
                    UnitPrice,
                    Quantity,
                    ServiceDate,
                    PeriodMonths__c,
                    DiscountAmountSum__c,
                    Opportunity.OrgA_OpportunityId__c,
                    PricebookEntry.Product2.Name 
                    FROM OpportunityLineitem WHERE Id In: recordIds
                ] ) requestRecords.add(requestOpportunityLineItemRecord(record));
            }
            when 'Revenue__c' {
                externalField_OrgC = 'OrgC_UriageId__c' ;
                externalField_OrgA = 'OrgA_UriageId__c' ;
                objectName_OrgA = 'Uriage__c' ;
                for( Revenue__c record : [
                    SELECT
                    Id,
                    SalesMonth__c,
                    Quantity__c,
                    UnitPrice__c,
                    TaxDifferenceAdjustment__c,
                    TaxRate__c,
                    ProductFamily__c,
                    AccountTitle__c,
                    ProductName__c,
                    FinalAccountProcess__c,
                    InvoiceInformation__r.OrgA_SeikyuId__c,
                    Opportunity__r.OrgA_OpportunityId__c
                    FROM Revenue__c WHERE Id In: recordIds
                ] ) requestRecords.add(requestUriageRecord(record));
            }
            when 'InvoiceInformation__c' {
                externalField_OrgC = 'OrgC_SeikyuId__c' ;
                externalField_OrgA = 'OrgA_SeikyuId__c' ;
                objectName_OrgA = 'Seikyu__c' ;
                for( InvoiceInformation__c record :  [
                    SELECT
                    Id,
                    PaymentDueDate__c,
                    IncludingTaxAmount__c,
                    TaxExcludedAmount__c,
                    CalculatingTax__c,
                    BillingDate__c,
                    Opportunity__r.Account.OrgA_AccountId__c
                    FROM InvoiceInformation__c WHERE Id In: recordIds
                ]  ) requestRecords.add(requestSeikyuRecord(record));
            }
        }
        if( requestRecords.size() == 0 ) return ;
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:orga/services/data/v59.0/composite/sobjects/'+objectName_OrgA+'/' + externalField_OrgC);
        req.setMethod('PATCH');
        req.setHeader('Accept','*/*' );
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        req.setTimeout(60000);
        req.setBody(
            JSON.serialize(new MAP<String,Object>{
                'allOrNone' => true,
                    'records' => requestRecords
                    })
        );
        HTTPResponse res = Test.isRunningTest() ? new HTTPResponse() : new Http().send(req);
        String resBody = Test.isRunningTest() ? JSON.serialize(new LIST<Result>{ new Result()} ) : res.getBody() ;
        callback( resBody );
        
    }
    public void callback( String resBody ){
        Integer i = 0 ;
        Response response = new Response();
        LIST<Sobject> sObjects = new LIST<Sobject>();
        for( Result result : (LIST<Result>)JSON.deserialize(resBody, LIST<Result>.CLASS) ){
            response.success = result.success ;        
            if( response.success == false ){
                response.error = resBody;
                responses.add(response);
                return ;
            }
            Id recordId = (Id)(requestRecords.get(i).get(externalField_OrgC)) ;
            i++ ;
            if( recordId == null ) continue ;
            Sobject sobj = recordId.getSobjectType().newSobject(recordId);
            sobj.put( externalField_OrgA , result.id );
            sObjects.add( sobj );
            
        }
        responses.add(response);
        SYSTEM.debug( response );
        update sObjects ;
    }
    public MAP<String,Object> requestAccountRecord(Account record){
        MAP<String,Object> requestRecord = new MAP<String,Object>();
        requestRecord.put('attributes', new MAP<String,String>{ 'type' => objectName_OrgA }) ;
        requestRecord.put(externalField_OrgC, record.Id );
        requestRecord.put('Name', record.Name );
        return requestRecord ;
    }
    public MAP<String,Object> requestOpportunityRecord(Opportunity record){
        MAP<String,Object> requestRecord = new MAP<String,Object>();
        requestRecord.put('attributes', new MAP<String,String>{ 'type' => objectName_OrgA }) ;
        requestRecord.put(externalField_OrgC, record.Id );
        requestRecord.put('Name', record.Name );
        requestRecord.put('CloseDate', record.CloseDate );
        requestRecord.put('StageName', record.StageName );
        requestRecord.put('ShiharaiSite__c', record.BillingCollectionSite__c );
        requestRecord.put('ShiharaiShudan__c', record.CollectionMethod__c );
        requestRecord.put('ShiharaiSite__c', record.BillingCollectionSite__c );
        requestRecord.put('AccountId', record.Account.OrgA_AccountId__c );
        requestRecord.put('RecordTypeId', '012H3000000NL0nIAG' );
        return requestRecord ;
    }
    public MAP<String,Object> requestOpportunityLineItemRecord(OpportunityLineItem record){
        MAP<String,Object> requestRecord = new MAP<String,Object>();
        requestRecord.put('attributes', new MAP<String,String>{ 'type' => objectName_OrgA }) ;
        requestRecord.put(externalField_OrgC, record.Id );
        requestRecord.put('PriceBookEntryId', '01uH3000000fpCqIAI' );
        requestRecord.put('UnitPrice', record.UnitPrice );
        requestRecord.put('ServiceDate', record.ServiceDate );
        requestRecord.put('Suryo__c', record.Quantity );
        requestRecord.put('Quantity', record.PeriodMonths__c );
        requestRecord.put('Nebiki1__c', record.DiscountAmountSum__c );
        requestRecord.put('OpportunityId', record.Opportunity.OrgA_OpportunityId__c );
        requestRecord.put('Shohinmei__c', record.PricebookEntry.Product2.Name  );
        return requestRecord ;
    }
    public MAP<String,Object> requestUriageRecord(Revenue__c record){
        MAP<String,Object> requestRecord = new MAP<String,Object>();
        requestRecord.put('attributes', new MAP<String,String>{ 'type' => objectName_OrgA }) ;
        requestRecord.put(externalField_OrgC, record.Id );
        requestRecord.put('Uriageduki__c', record.SalesMonth__c );
        requestRecord.put('Suryo__c', record.Quantity__c );
        requestRecord.put('Tanka__c', record.UnitPrice__c );
        requestRecord.put('ShohizeiSagakuChosei__c', record.TaxDifferenceAdjustment__c );
        requestRecord.put('TaxRateMaster__c', record.TaxRate__c );
        requestRecord.put('TaxRateMaster__c', record.TaxRate__c );
        requestRecord.put('KanjoKamoku__c', record.AccountTitle__c );
        requestRecord.put('Shohinmei__c', record.ProductName__c );
        requestRecord.put('Family__c', record.ProductFamily__c );
        requestRecord.put('KessanShori__c', record.FinalAccountProcess__c );
        requestRecord.put('Opportunity__c', record.Opportunity__r.OrgA_OpportunityId__c );
        requestRecord.put('Seikyu__c', record.InvoiceInformation__r.OrgA_SeikyuId__c );
        return requestRecord ;
    }
    public MAP<String,Object> requestSeikyuRecord(InvoiceInformation__c record){
        MAP<String,Object> requestRecord = new MAP<String,Object>();
        requestRecord.put('attributes', new MAP<String,String>{ 'type' => objectName_OrgA }) ;
        requestRecord.put(externalField_OrgC, record.Id );
        requestRecord.put('NyukinYoteibi__c', record.PaymentDueDate__c );
        requestRecord.put('Seikyugaku__c', record.IncludingTaxAmount__c );
        requestRecord.put('ZeinukiSeikyugaku__c', record.TaxExcludedAmount__c );
        requestRecord.put('Tax__c', record.CalculatingTax__c );
        requestRecord.put('Seikyubi__c', record.BillingDate__c );
        requestRecord.put('Account__c', record.Opportunity__r.Account.OrgA_AccountId__c );
        return requestRecord ;
    }
    
}