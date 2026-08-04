@isTest
private class RepositoryServiceTest {

    @isTest
    static void testGetRepositories(){

        Organization__c org =
            TestDataFactory.createOrganization();

        Project__c project =
            TestDataFactory.createProject(org.Id);

        TestDataFactory.createRepository(
            org.Id,
            project.Id
        );

        Test.startTest();

        List<Repository__c> repos =
            RepositoryService.getActiveRepositories();

        Test.stopTest();

        System.assertEquals(1,repos.size());

    }

}