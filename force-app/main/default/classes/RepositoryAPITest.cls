@isTest
private class RepositoryAPITest {

    @isTest
    static void testAPI(){

        RestRequest req =
            new RestRequest();

        RestResponse res =
            new RestResponse();

        RestContext.request=req;
        RestContext.response=res;

        RepositoryAPI.getRepositories();

        System.assertEquals(
            200,
            RestContext.response.statusCode
        );

    }

}