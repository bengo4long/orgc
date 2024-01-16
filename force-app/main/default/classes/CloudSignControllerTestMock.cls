global class CloudSignControllerTestMock implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"access_token":"12345","id":"testid"}');
        res.setStatusCode(200);
        return res;
    }
}