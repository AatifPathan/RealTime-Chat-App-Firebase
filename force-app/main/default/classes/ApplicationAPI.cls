@RestResource(urlMapping='/applications/*')
global with sharing class ApplicationAPI {

    @HttpPost
    global static String createApplication() {

        RestRequest req = RestContext.request;

        Application__c app =
            (Application__c)JSON.deserialize(
                req.requestBody.toString(),
                Application__c.class
            );

        insert app;

        return 'Application Created';

    }

}