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
    public OrgA__c orgA = OrgA__c.getInstance();
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
        objectName_OrgA = objectName == 'Revenue__c' ? 'Uriage__c' : objectName == 'InvoiceInformation__c' ? 'Seikyu__c' : objectName ;
        externalField_OrgC = externalField_OrgC(objectName_OrgA) ;
        externalField_OrgA = externalField_OrgA(objectName_OrgA) ;
    }
    public void sync(){
        SYSTEM.debug( objectName );
        switch on objectName {
            when 'Account' {
                for( Account record : [
                    SELECT 
                    Id, 
                    Name,
                    OrgA_AccountId__c,
                    VirtualAccountBank__c,
                    VirtualAccountNumber__c
                    FROM Account WHERE Id In: recordIds ] ) requestRecords.add(requestAccountRecord(record));
            }
            when 'Opportunity' {
                for( Opportunity record : [
                    SELECT 
                    Id, 
                    Name,
                    CloseDate, 
                    StageName, 
                    BillingCollectionSite__c, 
                    CollectionMethod__c,
                    Account.OrgA_AccountId__c,
                    AccountId
                    FROM Opportunity WHERE Id In: recordIds ] ) requestRecords.add(requestOpportunityRecord(record));
            }
            when 'OpportunityLineItem' {
                for( OpportunityLineitem record : [
                    SELECT
                    Id,
                    UnitPrice,
                    Quantity,
                    ServiceDate,
                    PeriodMonths__c,
                    DiscountAmount__c,
                    Opportunity.OrgA_OpportunityId__c,
                    OpportunityId,
                    PricebookEntry.Product2.Name 
                    FROM OpportunityLineitem WHERE Id In: recordIds
                ] ) requestRecords.add(requestOpportunityLineItemRecord(record));
            }
            when 'Revenue__c' {
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
                    Opportunity__r.OrgA_OpportunityId__c,
                    InvoiceInformation__c,
                    Opportunity__c
                    FROM Revenue__c WHERE Id In: recordIds
                ] ) requestRecords.add(requestUriageRecord(record));
            }
            when 'InvoiceInformation__c' {
                for( InvoiceInformation__c record :  [
                    SELECT
                    Id,
                    PaymentDueDate__c,
                    IncludingTaxAmount__c,
                    TaxExcludedAmount__c,
                    CalculatingTax__c,
                    BillingDate__c,
                    IncludeTaxAmount__c,
                    SalesTax__c,
                    TaxAmount__c,
                    BillingPaymentMethod__c,
                    SubscriberCode__c,
                    SubscriberName__c,
                    TransferDate__c,
                    Opportunity__r.Account.OrgA_AccountId__c,
                    Opportunity__r.AccountId
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
            //Id orgA_recordId = (Id)(requestRecords.get(i).get(externalField_OrgA)) ;
            i++ ;
            if( recordId == null ) continue ;
            Sobject sobj = recordId.getSobjectType().newSobject(recordId);
            sobj.put( externalField_OrgA , result.id );
            sObjects.add( sobj );
            
        }
        responses.add(response);
        update sObjects;
        //if( sObjects.size() > 0 ) new B54_Queueable(sObjects,'update');
    }
    public MAP<String,Object> requestAccountRecord(Account record){
        MAP<String,Object> requestRecord = new MAP<String,Object>();
        requestRecord.put('attributes', new MAP<String,String>{ 'type' => objectName_OrgA }) ;
        requestRecord.put(externalField_OrgC, record.Id );
        requestRecord.put('Name', record.Name );
        requestRecord.put('RecordTypeId', orgA.Account_OrgC_RecordTypeId__c );
        requestRecord.put('GinkoShitenmei__c', record.VirtualAccountBank__c );
        requestRecord.put('KozaBango__c', record.VirtualAccountNumber__c );
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
        //requestRecord.put('Account', requestRecord( 'Account', record.AccountId ) );
        requestRecord.put('RecordTypeId', orgA.Opportunity_OrgC_RecordTypeId__c );
        return requestRecord ;
    }
    public MAP<String,Object> requestOpportunityLineItemRecord(OpportunityLineItem record){
        MAP<String,Object> requestRecord = new MAP<String,Object>();
        requestRecord.put('attributes', new MAP<String,String>{ 'type' => objectName_OrgA }) ;
        requestRecord.put(externalField_OrgC, record.Id );
        requestRecord.put('PriceBookEntryId', orgA.PriceBookEntryId__c );
        requestRecord.put('UnitPrice', record.UnitPrice  * record.Quantity );
        requestRecord.put('ServiceDate', record.ServiceDate );
        requestRecord.put('Suryo__c', record.Quantity );
        requestRecord.put('Quantity', record.PeriodMonths__c );
        requestRecord.put('OpportunityId', record.Opportunity.OrgA_OpportunityId__c );
        //requestRecord.put('Opportunity', requestRecord( 'Opportunity', record.OpportunityId ) );
        requestRecord.put('Shohinmei__c', record.PricebookEntry.Product2.Name  );
        if( record.DiscountAmount__c != null ) for( Integer i = 1; i <= record.PeriodMonths__c; i++ )requestRecord.put('Nebiki'+i+'__c', record.DiscountAmount__c * record.Quantity );
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
        requestRecord.put('TaxRateMaster__c', record.TaxRate__c == null ? null : record.TaxRate__c == 0 ? '非課税' : String.ValueOf(record.TaxRate__c/100) );
        requestRecord.put('KanjoKamoku__c', record.AccountTitle__c );
        requestRecord.put('Shohinmei__c', record.ProductName__c );
        requestRecord.put('Family__c', record.ProductFamily__c );
        requestRecord.put('KessanShori__c', record.FinalAccountProcess__c );
        requestRecord.put('Opportunity__c', record.Opportunity__r.OrgA_OpportunityId__c );
        //requestRecord.put('Opportunity__r', requestRecord( 'Opportunity', record.Opportunity__c ) );
        requestRecord.put('Seikyu__c', record.InvoiceInformation__r.OrgA_SeikyuId__c );
        //if( record.InvoiceInformation__c != null ) requestRecord.put('Seikyu__r', requestRecord( 'Seikyu__c', record.InvoiceInformation__c ) );
        return requestRecord ;
    }
    public MAP<String,Object> requestSeikyuRecord(InvoiceInformation__c record){
        MAP<String,Object> requestRecord = new MAP<String,Object>();
        requestRecord.put('attributes', new MAP<String,String>{ 'type' => objectName_OrgA }) ;
        requestRecord.put(externalField_OrgC, record.Id );
        requestRecord.put('NyukinYoteibi__c', record.PaymentDueDate__c );
        requestRecord.put('ShiharaiShudan__c', record.BillingPaymentMethod__c );
        requestRecord.put('Seikyugaku__c', record.IncludeTaxAmount__c );
        requestRecord.put('ZeinukiSeikyugaku__c', record.TaxExcludedAmount__c );
        requestRecord.put('Tax__c', record.TaxAmount__c );
        requestRecord.put('UriageTax__c', record.SalesTax__c );
        requestRecord.put('Seikyubi__c', record.BillingDate__c );
        requestRecord.put('Furikaebi__c', record.TransferDate__c );
        requestRecord.put('DataCoordinationDate__c', Date.today() );
        //requestRecord.put('kanyusya_name__c', record.SubscriberName__c );
        requestRecord.put('Account__c', record.Opportunity__r.Account.OrgA_AccountId__c );
        //requestRecord.put('Account__r', requestRecord( 'Account', record.Opportunity__r.AccountId ) );
        return requestRecord ;
    }
    
    //public MAP<String,Object> requestRecord(String objectName, Id recordId){
    //    MAP<String,Object> requestRecord = new MAP<String,Object>();
    //    requestRecord.put('attributes', new MAP<String,String>{ 'type' => objectName }) ;
    //    requestRecord.put( externalField_OrgC(objectName), recordId );
    //    return requestRecord ;
    //}
    
    public String externalField_OrgC(String objectName){
        return 'OrgC_' + objectName.removeEnd('__c') + 'Id__c' ;
    }
    public String externalField_OrgA(String objectName){
        return 'OrgA_' + objectName.removeEnd('__c') + 'Id__c' ;        
    }
}