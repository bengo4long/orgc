global with sharing class CloudSignController {
    public static CloudSignApiSettings__c  settings = CloudSignApiSettings__c.getInstance();

    @InvocableMethod(label='クラウドサインにPDFを送信')
    public static List<String> sendPdf(List<SendPdfParameters> params) {
        SendPdfParameters param = params[0];
        String clientId = param.clientId;
        Id pdfId = param.pdfId;
        Id oppId = param.oppId;
        String managerName = param.managerName;
        String managerEmail = param.managerEmail;
        String approverName = param.approverName;
        String approverEmail = param.approverEmail;

        String host = settings.ApiUrlHost__c;

        String token = getToken(clientId);

        HttpResponse res = setDocument(token, host, clientId, pdfId);
        if (res.getStatusCode() != 200) {
            return new List<String>{'error'};
        }

        Map<String, Object> resMap   = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        String resBody = res.getBody();
        String documentId = getParam(resBody, 'id');

        res = sendPdf(token, documentId, host, clientId, pdfId, oppId);
        if (res.getStatusCode() != 200) {
            return new List<String>{'error'};
        }

        res = addApprover(token, documentId, host, clientId, managerName, managerEmail);
        if (res.getStatusCode() != 200) {
            return new List<String>{'error'};
        }

        res = addApprover(token, documentId, host, clientId, approverName, approverEmail);
        if (res.getStatusCode() != 200) {
            return new List<String>{'error'};
        }

        res = sendDocument(token, host, documentId);
        if (res.getStatusCode() != 200) {
            return new List<String>{'error'};
        }
        return new List<String>{ documentId };
    }

    public static HttpResponse setDocument(String token, String host, String clientId, Id pdfId) {
        ContentDocument cd = [SELECT Id, Title FROM ContentDocument WHERE Id = :pdfId][0];
        String pdfName = ( cd.Title.removeEnd('.pdf') );

        HttpRequest documentReq = new HttpRequest();
        String endPoint = host + 'documents';
        String requestBody = encodeFromMap(new Map<String, String>{'title'=>pdfName});

        documentReq.setEndpoint(endpoint);
        documentReq.setMethod('POST');
        documentReq.setBody(requestBody);
        documentReq.setHeader('Accept','application/json');
        documentReq.setHeader('Content-Type','application/x-www-form-urlencoded');
        documentReq.setHeader('Authorization', 'Bearer ' + token );

        return new Http().send(documentReq);
    }

    public static HttpResponse sendPdf(String token, String documentId, String host, String clientId, Id pdfId, Id oppId) {
        HttpRequest documentFilesReq = new HttpRequest();
        String endPoint = host + 'documents/' + documentId + '/files';

        ContentVersion file = [SELECT Id,  VersionData  FROM ContentVersion WHERE ContentDocumentId = :pdfId][0];
        Blob body = file.VersionData;

        return uploadFile(documentId, body, oppId + '.pdf', token, host);
    }

    public static HttpResponse addApprover(String token, String documentId, String host, String clientId, String name, String email) {
        HttpRequest documentReq = new HttpRequest();
        String endPoint = host + 'documents/' + documentId + '/participants';
        String requestBody = encodeFromMap(new Map<String, String>{'name'=>name, 'email'=>email});

        documentReq.setEndpoint(endpoint);
        documentReq.setMethod('POST');
        documentReq.setBody(requestBody);
        documentReq.setHeader('Accept','application/json');
        documentReq.setHeader('Content-Type','application/x-www-form-urlencoded');
        documentReq.setHeader('Authorization', 'Bearer ' + token );

        return new Http().send(documentReq);
    }

    public static HttpResponse sendDocument(String token, String host, String documentId) {
        HttpRequest documentReq = new HttpRequest();
        String endPoint = host + 'documents/' + documentId;

        documentReq.setEndpoint(endpoint);
        documentReq.setMethod('POST');
        documentReq.setHeader('Accept','application/json');
        documentReq.setHeader('Content-Type','application/x-www-form-urlencoded');
        documentReq.setHeader('Authorization', 'Bearer ' + token );

        return new Http().send(documentReq);
    }

    private static String getToken(String clientId) {
        String host = settings.ApiUrlHost__c;
        String endPoint = host + 'token';
        HttpRequest req = new HttpRequest();

        req.setEndpoint(endpoint);
        req.setMethod('POST');
        String tokenRequestBody = encodeFromMap(new Map<String, String>{ 'client_id' => clientId});
        req.setBody(tokenRequestBody);
        req.setHeader('Accept','application/json');
        req.setHeader('Content-Type','application/x-www-form-urlencoded');

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> resMap   = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String)resMap.get('access_token');
        }
        return res.getBody();
    }

    global class SendPdfParameters {
        @invocableVariable
        public String oppId;
        @invocableVariable
        public String clientId;
        @invocableVariable
        public Id pdfId;
        @invocableVariable
        public String managerName;
        @invocableVariable
        public String managerEmail;
        @invocableVariable
        public String approverName;
        @invocableVariable
        public String approverEmail;
    }

    public static String encodeFromMap(Map<String, String> fromMap){
        String data = '';
        for(String key : fromMap.keySet()) {
            if (fromMap.containsKey(key) && fromMap.get(key) != null){
                data += EncodingUtil.urlEncode(key, 'UTF-8') + '=' + EncodingUtil.urlEncode(fromMap.get(key), 'UTF-8') + '&';
            }
        }
        return data.removeEnd('&'); 
    }

    public static String getParam( String s , String param ){
        List<String> paramList = s.split('"'+param+'":"|","');
        if (paramList.size() <= 1) return null;
        s = paramList[1] ;
        System.debug( s );
        return s ;
    }

    public static HttpResponse uploadFile( String documentId, Blob fileBody, String fileName, String token, String host ) {
        string form64 = '';
        string contentType = GetContentType();
        form64 += WriteBoundary();
        form64 += WriteBlobBodyParameter('uploadfile', EncodingUtil.base64Encode(fileBody), fileName);
        blob formBlob = EncodingUtil.base64Decode(form64);
        string contentLength = string.valueOf(formBlob.size());

        HttpRequest req = new HttpRequest();

        String endPoint = host + 'documents/'+documentId+'/files';

        req.setEndpoint(endpoint);
        req.setMethod('POST');

        req.setHeader('Accept','application/json');
        req.setHeader('Connection', 'keep-alive');
        req.setHeader('Content-Length', contentLength);
        req.setHeader('Content-Type', contentType);
        req.setHeader('Authorization', 'Bearer ' + token );

        req.setBodyAsBlob(formBlob);
        req.setTimeout(120000);

        return new Http().send(req);
    }

    //  The boundary is alligned so it doesn't produce padding characters when base64 encoded.
    private final static string Boundary = '1ff13444ed8140c7a32fc4e6451aa76d';

    public static string GetContentType() {
        return 'multipart/form-data; charset="UTF-8"; boundary="' + Boundary + '"';
    }

    public static string WriteBoundary() {
        string value = '--' + Boundary + '\r\n';
        blob valueBlob = blob.valueOf(value);

        return EncodingUtil.base64Encode(valueBlob);
    }

    public static string WriteBoundary(
        EndingType ending) {
        string value = '';

        if (ending == EndingType.Cr) {
            value += '\n';
        } else if (ending == EndingType.None) {
            value += '\r\n';
        }
        value += '--' + Boundary + '--';

        blob valueBlob = blob.valueOf(value);

        return EncodingUtil.base64Encode(valueBlob);
    }

    public static string WriteBlobBodyParameter(string key, string file64, string fileName) {
        
        String mimeType = resolveMimeType(fileName);
        
        string contentDisposition = 'Content-Disposition: form-data; name="' + key + '"; filename="'+fileName+'"';
        string contentDispositionCrLf = contentDisposition + '\r\n';
        blob contentDispositionCrLfBlob = blob.valueOf(contentDispositionCrLf);
        string contentDispositionCrLf64 = EncodingUtil.base64Encode(contentDispositionCrLfBlob);
        string content = SafelyPad(contentDisposition, contentDispositionCrLf64, '\r\n');

        string contentTypeHeader = 'Content-Type: ' + mimeType;
        string contentTypeCrLf = contentTypeHeader + '\r\n\r\n';
        blob contentTypeCrLfBlob = blob.valueOf(contentTypeCrLf);
        string contentTypeCrLf64 = EncodingUtil.base64Encode(contentTypeCrLfBlob);
        content += SafelyPad(contentTypeHeader, contentTypeCrLf64, '\r\n\r\n');
        
        integer file64Length = file64.length();
        String last4Bytes = file64.substring(file64.length()-4,file64.length());

        EndingType ending = EndingType.None;
        if (last4Bytes.endsWith('==')) {
            last4Bytes = last4Bytes.substring(0,2) + '0K';
            file64 = file64.substring(0,file64.length()-4) + last4Bytes;

            ending = EndingType.CrLf;
        } else if (last4Bytes.endsWith('=')) {
            last4Bytes = last4Bytes.substring(0,3) + 'N';
        	file64 = file64.substring(0,file64.length()-4) + last4Bytes;

            ending = EndingType.Cr;
        }
               
        content += file64;
        
        content += WriteBoundary(ending);
        return content;
    }

    private static String resolveMimeType(String fileName) {
        String fileType = fileName.substringAfterLast('.');
        String mimeType = 'image/png'; // fallback value
        if (fileType.equalsIgnoreCase('png')) {
            mimeType = 'image/png';
        } else if (fileType.equalsIgnoreCase('jpeg') || fileType.equalsIgnoreCase('jpg')) {
            mimeType = 'image/jpg';
        } else if (fileType.equalsIgnoreCase('pgm')) {
            mimeType = 'image/x-portable-graymap';
        } else if (fileType.equalsIgnoreCase('ppm')) {
            mimeType = 'image/x-portable-pixmap';            
        }
        return mimeType;
    }

    public static string SafelyPad(
        string value,
        string valueCrLf64,
        string lineBreaks) {
        string valueCrLf = '';
        blob valueCrLfBlob = null;

        while (valueCrLf64.endsWith('=')) {
            value += ' ';
            valueCrLf = value + lineBreaks;
            valueCrLfBlob = blob.valueOf(valueCrLf);
            valueCrLf64 = EncodingUtil.base64Encode(valueCrLfBlob);
        }

        return valueCrLf64;
    }

    public enum EndingType {
        Cr,
        CrLf,
        None
    }
}