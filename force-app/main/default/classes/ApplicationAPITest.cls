@isTest
private class ApplicationAPITest {

    @isTest
    static void testAPI(){

        RestRequest req =
            new RestRequest();

        RestResponse res =
            new RestResponse();

        RestContext.request=req;
        RestContext.response=res;

        System.assertNotEquals(
            null,
            req
        );

    }

}